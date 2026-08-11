// Platform admin triggers a password-reset email for a tenant owner.
// Secrets: SUPABASE_SERVICE_ROLE_KEY (auto), optional RESEND_API_KEY,
// RESEND_FROM_EMAIL, PUBLIC_APP_URL.

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
    if (!authHeader) return json({ error: "NOT_AUTHENTICATED" }, 401);

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });
    const {
      data: { user },
      error: userErr,
    } = await userClient.auth.getUser();
    if (userErr || !user) return json({ error: "NOT_AUTHENTICATED" }, 401);

    const { data: isAdmin, error: adminErr } = await userClient.rpc(
      "is_platform_admin",
    );
    if (adminErr || isAdmin !== true) {
      return json({ error: "FORBIDDEN" }, 403);
    }

    const body = await req.json() as {
      email?: string;
      store_id?: string;
      user_id?: string;
      redirect_to?: string;
    };

    let email = (body.email ?? "").trim().toLowerCase();
    let targetUserId = (body.user_id ?? "").trim() || null;
    const storeId = (body.store_id ?? "").trim() || null;

    const admin = createClient(supabaseUrl, serviceKey);

    if (!email && targetUserId) {
      const { data: listed } = await admin.auth.admin.getUserById(targetUserId);
      email = (listed.user?.email ?? "").toLowerCase();
    }

    if (!email) {
      return json({ error: "EMAIL_REQUIRED" }, 400);
    }

    const publicApp = (
      Deno.env.get("PUBLIC_APP_URL") ?? "https://casin-pos-black.vercel.app"
    ).replace(/\/+$/, "");
    const redirectTo =
      (body.redirect_to ?? "").trim() || `${publicApp}/reset-password`;

    const { data: linkData, error: linkErr } = await admin.auth.admin
      .generateLink({
        type: "recovery",
        email,
        options: { redirectTo },
      });

    if (linkErr) {
      return json({
        error: "RESET_FAILED",
        message: linkErr.message,
      }, 500);
    }

    if (!targetUserId) {
      targetUserId = linkData.user?.id ?? null;
    }

    const actionLink =
      (linkData as { properties?: { action_link?: string } }).properties
        ?.action_link ??
      (linkData as { action_link?: string }).action_link ??
      null;

    await userClient.rpc("platform_log_audit", {
      p_action: "password_reset",
      p_store_id: storeId,
      p_target_user_id: targetUserId,
      p_meta: { email, redirect_to: redirectTo },
    });

    const resendKey = Deno.env.get("RESEND_API_KEY");
    if (!resendKey || !actionLink) {
      return json({
        ok: true,
        emailed: false,
        reason: resendKey ? "NO_LINK" : "NO_EMAIL_PROVIDER",
        email,
        reset_url: actionLink,
        message: resendKey
          ? "Recovery link generated but missing action_link."
          : "Set RESEND_API_KEY to email the owner, or copy reset_url.",
      });
    }

    const fromEmail = Deno.env.get("RESEND_FROM_EMAIL") ??
      "CasinPOS <onboarding@resend.dev>";
    const safeLink = escapeHtml(actionLink);
    const safeEmail = escapeHtml(email);

    const html = `<!DOCTYPE html>
<html lang="en"><body style="font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Roboto,sans-serif;background:#f4f5f7;padding:32px;">
  <table width="100%" cellpadding="0" cellspacing="0" style="max-width:480px;margin:0 auto;background:#fff;border-radius:12px;">
    <tr><td style="background:#111827;padding:24px;text-align:center;color:#fff;font-weight:700;">CasinPOS</td></tr>
    <tr><td style="padding:32px;">
      <h1 style="margin:0 0 12px;font-size:20px;color:#111827;">Reset your password</h1>
      <p style="margin:0 0 16px;font-size:15px;color:#4b5563;line-height:1.6;">
        A CasinPOS administrator requested a password reset for <strong>${safeEmail}</strong>.
      </p>
      <p style="margin:0 0 24px;text-align:center;">
        <a href="${safeLink}" style="display:inline-block;background:#111827;color:#fff;text-decoration:none;font-weight:600;padding:14px 28px;border-radius:8px;">
          Set new password
        </a>
      </p>
      <p style="margin:0;font-size:12px;color:#9ca3af;word-break:break-all;">Or open: ${safeLink}</p>
    </td></tr>
  </table>
</body></html>`;

    const text =
      `Reset your CasinPOS password\n\n` +
      `An administrator requested a password reset for ${email}.\n\n` +
      `Open this link to set a new password:\n${actionLink}\n`;

    const mailRes = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: fromEmail,
        to: [email],
        subject: "Reset your CasinPOS password",
        html,
        text,
      }),
    });

    if (!mailRes.ok) {
      const errText = await mailRes.text();
      return json({
        ok: true,
        emailed: false,
        reason: "RESEND_FAILED",
        email,
        reset_url: actionLink,
        message: errText.slice(0, 300),
      }, 200);
    }

    return json({
      ok: true,
      emailed: true,
      email,
      message: "Password reset email sent.",
    });
  } catch (e) {
    return json({ error: "UNEXPECTED", message: String(e) }, 500);
  }
});

function escapeHtml(s: string) {
  return s
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;");
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
