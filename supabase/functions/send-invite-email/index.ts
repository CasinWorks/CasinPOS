// Supabase Edge Function: send-invite-email
// Secrets (Dashboard → Edge Functions → Secrets, or `supabase secrets set`):
//   RESEND_API_KEY     — required to actually send (https://resend.com)
//   RESEND_FROM_EMAIL  — optional, default "CasinPOS <onboarding@resend.dev>"
//   PUBLIC_APP_URL     — optional, default https://casin-pos-black.vercel.app
//   SUPABASE_SERVICE_ROLE_KEY — auto-injected on hosted Supabase
//
// Without RESEND_API_KEY the function still returns invite_url so the client can
// show Copy link / mailto backup.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return json({ error: "METHOD_NOT_ALLOWED" }, 405);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const anonKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !anonKey || !serviceKey) {
      return json({ error: "SERVER_MISCONFIGURED" }, 500);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "NOT_AUTHENTICATED" }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userErr,
    } = await userClient.auth.getUser();
    if (userErr || !user) {
      return json({ error: "NOT_AUTHENTICATED" }, 401);
    }

    const body = await req.json() as {
      email?: string;
      token?: string;
      store_name?: string;
      role?: string;
      invite_url?: string;
      inviter_name?: string;
    };

    const email = (body.email ?? "").trim().toLowerCase();
    const token = (body.token ?? "").trim();
    if (!email || !token) {
      return json({ error: "EMAIL_AND_TOKEN_REQUIRED" }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: inv, error: invErr } = await admin
      .from("store_invitations")
      .select("id, email, role, store_id, invited_by, status, expires_at, stores(name)")
      .eq("token", token)
      .eq("status", "pending")
      .maybeSingle();

    if (invErr || !inv) {
      return json({ error: "INVITE_NOT_FOUND" }, 404);
    }
    if (String(inv.email).toLowerCase() !== email) {
      return json({ error: "EMAIL_MISMATCH" }, 400);
    }

    // Caller must be the inviter or an owner/admin of the store.
    const isInviter = inv.invited_by === user.id;
    if (!isInviter) {
      const { data: member } = await admin
        .from("store_members")
        .select("role")
        .eq("store_id", inv.store_id)
        .eq("user_id", user.id)
        .eq("status", "active")
        .maybeSingle();
      const role = member?.role as string | undefined;
      if (role !== "owner" && role !== "admin") {
        return json({ error: "FORBIDDEN" }, 403);
      }
    }

    const publicApp =
      (Deno.env.get("PUBLIC_APP_URL") ?? "https://casin-pos-black.vercel.app")
        .replace(/\/+$/, "");
    const inviteUrl = (body.invite_url?.trim()) ||
      `${publicApp}/invite?token=${encodeURIComponent(token)}`;

    const storeRow = inv.stores as { name?: string } | null;
    const storeName = (body.store_name?.trim()) ||
      storeRow?.name ||
      "CasinPOS";
    const roleRaw = (body.role ?? inv.role ?? "staff").toString();
    const roleName = titleCaseRole(roleRaw);
    const inviterName = resolveInviterName(body.inviter_name, user);
    const expiryDays = resolveExpiryDays(inv.expires_at);
    const year = String(new Date().getFullYear());

    const resendKey = Deno.env.get("RESEND_API_KEY");
    if (!resendKey) {
      return json({
        emailed: false,
        reason: "NO_EMAIL_PROVIDER",
        invite_url: inviteUrl,
        message:
          "Set RESEND_API_KEY (and optional RESEND_FROM_EMAIL, PUBLIC_APP_URL) in Supabase Edge Function secrets to enable invite emails.",
      });
    }

    const fromEmail = Deno.env.get("RESEND_FROM_EMAIL") ??
      "CasinPOS <onboarding@resend.dev>";

    const storeNameHtml = escapeHtml(storeName);
    const inviterNameHtml = escapeHtml(inviterName);
    const roleNameHtml = escapeHtml(roleName);
    const inviteUrlHtml = escapeHtml(inviteUrl);
    const tokenHtml = escapeHtml(token);
    const expiryDaysHtml = escapeHtml(String(expiryDays));
    const yearHtml = escapeHtml(year);

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8" />
<meta name="viewport" content="width=device-width, initial-scale=1.0" />
<title>You've been invited to join ${storeNameHtml} on CasinPOS</title>
</head>
<body style="margin:0; padding:0; background-color:#f4f5f7; font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,Helvetica,Arial,sans-serif;">
  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background-color:#f4f5f7; padding:32px 16px;">
    <tr>
      <td align="center">
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px; background-color:#ffffff; border-radius:12px; overflow:hidden; box-shadow:0 1px 3px rgba(0,0,0,0.08);">

          <!-- Header / Brand -->
          <tr>
            <td style="background-color:#111827; padding:28px 32px; text-align:center;">
              <span style="font-size:20px; font-weight:700; color:#ffffff; letter-spacing:-0.02em;">CasinPOS</span>
            </td>
          </tr>

          <!-- Body -->
          <tr>
            <td style="padding:36px 32px 8px 32px;">
              <h1 style="margin:0 0 12px 0; font-size:22px; line-height:1.3; color:#111827; font-weight:700;">
                You're invited to join ${storeNameHtml}
              </h1>
              <p style="margin:0 0 16px 0; font-size:15px; line-height:1.6; color:#4b5563;">
                <strong>${inviterNameHtml}</strong> has invited you to join <strong>${storeNameHtml}</strong> on CasinPOS
                as a <strong>${roleNameHtml}</strong>.
              </p>
              <p style="margin:0 0 24px 0; font-size:15px; line-height:1.6; color:#4b5563;">
                Accept the invite below to set up your login and start using the app with your team.
              </p>
            </td>
          </tr>

          <!-- Role / Store info card -->
          <tr>
            <td style="padding:0 32px 24px 32px;">
              <table role="presentation" width="100%" cellpadding="0" cellspacing="0"
                     style="background-color:#f9fafb; border:1px solid #e5e7eb; border-radius:8px;">
                <tr>
                  <td style="padding:16px 20px;">
                    <p style="margin:0 0 4px 0; font-size:12px; color:#9ca3af; text-transform:uppercase; letter-spacing:0.04em;">Store</p>
                    <p style="margin:0 0 12px 0; font-size:14px; color:#111827; font-weight:600;">${storeNameHtml}</p>
                    <p style="margin:0 0 4px 0; font-size:12px; color:#9ca3af; text-transform:uppercase; letter-spacing:0.04em;">Role</p>
                    <p style="margin:0; font-size:14px; color:#111827; font-weight:600;">${roleNameHtml}</p>
                  </td>
                </tr>
              </table>
            </td>
          </tr>

          <!-- CTA -->
          <tr>
            <td style="padding:0 32px 12px 32px;" align="center">
              <a href="${inviteUrlHtml}"
                 style="display:inline-block; background-color:#111827; color:#ffffff; text-decoration:none;
                        font-size:15px; font-weight:600; padding:14px 28px; border-radius:8px;
                        mso-line-height-rule:exactly;">
                Accept Invitation
              </a>
            </td>
          </tr>

          <!-- Expiry note -->
          <tr>
            <td style="padding:0 32px 28px 32px;" align="center">
              <p style="margin:0; font-size:13px; color:#9ca3af;">
                This invite link expires in ${expiryDaysHtml} days.
              </p>
            </td>
          </tr>

          <!-- Fallback link — nowrap on href URL; word-break only for display wrapping -->
          <tr>
            <td style="padding:0 32px 16px 32px;">
              <p style="margin:0 0 8px 0; font-size:13px; line-height:1.6; color:#9ca3af;">
                Or copy and paste this link into your browser:
              </p>
              <p style="margin:0; font-size:12px; line-height:1.5;">
                <a href="${inviteUrlHtml}"
                   style="color:#2563eb; word-break:break-all; overflow-wrap:anywhere; text-decoration:underline;">${inviteUrlHtml}</a>
              </p>
            </td>
          </tr>

          <!-- Bare token backup (no mid-token soft breaks) -->
          <tr>
            <td style="padding:0 32px 28px 32px;">
              <p style="margin:0 0 6px 0; font-size:12px; line-height:1.5; color:#9ca3af;">
                If the link breaks, sign in at CasinPOS → Join your team, and paste this token:
              </p>
              <p style="margin:0; font-family:ui-monospace,SFMono-Regular,Menlo,Monaco,Consolas,monospace;
                        font-size:12px; line-height:1.5; color:#111827; word-break:keep-all; white-space:nowrap;">
                ${tokenHtml}
              </p>
            </td>
          </tr>

          <!-- Divider -->
          <tr>
            <td style="padding:0 32px;">
              <hr style="border:none; border-top:1px solid #e5e7eb; margin:0;" />
            </td>
          </tr>

          <!-- Footer -->
          <tr>
            <td style="padding:24px 32px 32px 32px;">
              <p style="margin:0 0 6px 0; font-size:13px; line-height:1.6; color:#9ca3af;">
                If you weren't expecting this invite, you can safely ignore this email.
              </p>
              <p style="margin:0 0 10px 0; font-size:13px; line-height:1.6; color:#9ca3af;">
                — The CasinPOS Team
              </p>
              <p style="margin:0; font-size:11px; line-height:1.5; color:#c0c4cc;">
                Powered by <a href="https://www.casinworks.com" style="color:#9ca3af; text-decoration:underline;">CASINWORKS</a>
              </p>
            </td>
          </tr>

        </table>

        <!-- Bottom legal -->
        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:480px; margin-top:16px;">
          <tr>
            <td align="center">
              <p style="margin:0; font-size:12px; color:#9ca3af;">
                © ${yearHtml} CasinPOS. All rights reserved.
              </p>
            </td>
          </tr>
        </table>

      </td>
    </tr>
  </table>
</body>
</html>`;

    const text =
      `You've been invited to join ${storeName} on CasinPOS\n\n` +
      `${inviterName} has invited you to join ${storeName} on CasinPOS as a ${roleName}.\n\n` +
      `Accept the invite to set up your login and start using the app with your team:\n` +
      `${inviteUrl}\n\n` +
      `If the link does not open cleanly, sign in at ${publicApp} → Join your team,\n` +
      `and paste this invite token (copy the whole line):\n` +
      `${token}\n\n` +
      `Store: ${storeName}\n` +
      `Role: ${roleName}\n\n` +
      `This invite link expires in ${expiryDays} days.\n\n` +
      `If you weren't expecting this invite, you can safely ignore this email.\n\n` +
      `— The CasinPOS Team\n` +
      `Powered by CASINWORKS (https://www.casinworks.com)\n` +
      `© ${year} CasinPOS. All rights reserved.\n`;

    const res = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [email],
        subject: `You've been invited to join ${storeName} on CasinPOS`,
        html,
        text,
      }),
    });

    if (!res.ok) {
      const detail = await res.text();
      console.error("Resend error", res.status, detail);
      return json({
        emailed: false,
        reason: "RESEND_FAILED",
        invite_url: inviteUrl,
        message: "Email provider rejected the send. Use Copy invite link as backup.",
      }, 502);
    }

    return json({
      emailed: true,
      invite_url: inviteUrl,
    });
  } catch (e) {
    console.error(e);
    return json({ error: "INTERNAL", message: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

function escapeHtml(s: string) {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function titleCaseRole(role: string): string {
  return role
    .trim()
    .split(/[\s_-]+/)
    .filter(Boolean)
    .map((w) => w.charAt(0).toUpperCase() + w.slice(1).toLowerCase())
    .join(" ") || "Staff";
}

function resolveInviterName(
  fromBody: string | undefined,
  user: { email?: string | null; user_metadata?: Record<string, unknown> },
): string {
  const bodyName = fromBody?.trim();
  if (bodyName) return bodyName;

  const meta = user.user_metadata ?? {};
  for (const key of ["full_name", "name", "display_name"]) {
    const v = meta[key];
    if (typeof v === "string" && v.trim()) return v.trim();
  }

  const email = user.email?.trim();
  if (email?.includes("@")) {
    const local = email.split("@")[0]?.trim();
    if (local) return local;
  }
  if (email) return email;

  return "A teammate";
}

function resolveExpiryDays(expiresAt: unknown): number {
  if (expiresAt == null || expiresAt === "") return 7;
  const ms = Date.parse(String(expiresAt));
  if (Number.isNaN(ms)) return 7;
  const days = Math.ceil((ms - Date.now()) / (1000 * 60 * 60 * 24));
  if (!Number.isFinite(days) || days < 1) return 7;
  return days;
}
