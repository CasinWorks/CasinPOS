// PayMongo webhook → lifetime CasinPOS Premium (one-time unlock).
// Dashboard: Developers → Webhooks →
//   URL https://<project>.supabase.co/functions/v1/paymongo-webhook
//   Events: checkout_session.payment.paid
// Secrets: PAYMONGO_WEBHOOK_SECRET, SUPABASE_SERVICE_ROLE_KEY (auto)

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "paymongo-signature, content-type, authorization",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const LIFETIME_END = "2099-12-31T23:59:59.000Z";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return json({ error: "METHOD_NOT_ALLOWED" }, 405);
    }

    const expected = (Deno.env.get("PAYMONGO_WEBHOOK_SECRET") ?? "").trim();
    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!expected || !supabaseUrl || !serviceKey) {
      return json({ error: "SERVER_MISCONFIGURED" }, 500);
    }

    const raw = await req.text();
    const sigHeader = req.headers.get("Paymongo-Signature") ??
      req.headers.get("paymongo-signature") ??
      "";
    const okSig = await verifyPaymongoSignature(raw, sigHeader, expected);
    if (!okSig) {
      return json({ error: "UNAUTHORIZED" }, 401);
    }

    let body: Record<string, unknown>;
    try {
      body = JSON.parse(raw) as Record<string, unknown>;
    } catch {
      return json({ error: "INVALID_JSON" }, 400);
    }

    const event = unwrapEvent(body);
    if (!event) return json({ ok: true, skipped: "no_event" });

    const type = event.type;
    if (
      type !== "checkout_session.payment.paid" &&
      type !== "payment.paid"
    ) {
      return json({ ok: true, skipped: "unhandled", type });
    }

    const checkoutId = event.checkoutId;
    const paymentId = event.paymentId;
    let storeId = event.storeId;

    const admin = createClient(supabaseUrl, serviceKey);

    if (!storeId && checkoutId) {
      const { data: row } = await admin
        .from("billing_checkout_sessions")
        .select("store_id")
        .eq("paymongo_checkout_id", checkoutId)
        .maybeSingle();
      storeId = (row?.store_id as string | undefined) ?? null;
    }

    if (!storeId) {
      return json({ ok: true, skipped: "store_not_found", checkoutId });
    }

    if (paymentId) {
      const { data: already } = await admin
        .from("billing_checkout_sessions")
        .select("id, status")
        .eq("paymongo_payment_id", paymentId)
        .maybeSingle();
      if (already?.status === "paid") {
        return json({ ok: true, skipped: "already_paid", paymentId });
      }
    }

    if (checkoutId) {
      await admin
        .from("billing_checkout_sessions")
        .update({
          status: "paid",
          paymongo_payment_id: paymentId,
          paid_at: new Date().toISOString(),
          updated_at: new Date().toISOString(),
        })
        .eq("paymongo_checkout_id", checkoutId)
        .eq("status", "pending");
    }

    const { data: sub } = await admin
      .from("subscriptions")
      .select("provider, current_period_end")
      .eq("store_id", storeId)
      .maybeSingle();

    // Already lifetime — don't overwrite bind id unnecessarily.
    const existingEnd = Date.parse(String(sub?.current_period_end ?? ""));
    if (
      (sub?.provider as string | undefined) === "paymongo" &&
      !Number.isNaN(existingEnd) &&
      existingEnd >= Date.parse(LIFETIME_END) - 24 * 60 * 60 * 1000
    ) {
      return json({ ok: true, skipped: "already_lifetime", storeId });
    }

    const now = Date.now();
    const bindId = paymentId || checkoutId || `paymongo:${storeId}:${now}`;
    const { error } = await admin.rpc("apply_store_subscription_from_provider", {
      p_store_id: storeId,
      p_plan_tier: "premium",
      p_status: "active",
      p_provider: "paymongo",
      p_provider_customer_id: checkoutId,
      p_provider_subscription_id: bindId,
      p_period_start: new Date(now).toISOString(),
      p_period_end: LIFETIME_END,
      p_monthly_limit: 100000,
    });
    if (error) {
      const msg = error.message ?? "";
      if (msg.includes("SUBSCRIPTION_BOUND_TO_OTHER_STORE")) {
        return json({
          ok: true,
          skipped: "subscription_bound_to_other_store",
          message: error.message,
        });
      }
      return json({ error: "APPLY_FAILED", message: error.message }, 500);
    }

    return json({
      ok: true,
      store_id: storeId,
      provider: "paymongo",
      period_end: LIFETIME_END,
    });
  } catch (e) {
    return json({ error: "UNEXPECTED", message: String(e) }, 500);
  }
});

type ParsedEvent = {
  type: string;
  checkoutId: string | null;
  paymentId: string | null;
  storeId: string | null;
};

function unwrapEvent(body: Record<string, unknown>): ParsedEvent | null {
  const data = body.data as Record<string, unknown> | undefined;
  const attrs = (data?.attributes ?? body) as Record<string, unknown>;
  const type = String(attrs.type ?? body.type ?? "");
  if (!type) return null;

  const inner = (attrs.data ?? data) as Record<string, unknown> | undefined;
  const innerAttrs = (inner?.attributes ?? {}) as Record<string, unknown>;
  const metadata = (innerAttrs.metadata ?? {}) as Record<string, unknown>;

  let checkoutId: string | null = null;
  let paymentId: string | null = null;

  if (String(inner?.type ?? "") === "checkout_session" && inner?.id) {
    checkoutId = String(inner.id);
  }
  if (type.startsWith("checkout_session") && inner?.id) {
    checkoutId = checkoutId ?? String(inner.id);
  }

  const payments = innerAttrs.payments;
  if (Array.isArray(payments) && payments.length > 0) {
    const first = payments[0] as Record<string, unknown>;
    const pid = first.id ??
      (first.data as Record<string, unknown> | undefined)?.id;
    if (pid) paymentId = String(pid);
  }

  if (String(inner?.type ?? "") === "payment" && inner?.id) {
    paymentId = String(inner.id);
    const cs = innerAttrs.checkout_session_id ??
      (innerAttrs.source as Record<string, unknown> | undefined)?.id;
    if (cs) checkoutId = String(cs);
  }

  const storeId = metadata.store_id
    ? String(metadata.store_id)
    : null;

  return { type, checkoutId, paymentId, storeId };
}

async function verifyPaymongoSignature(
  raw: string,
  header: string,
  secret: string,
): Promise<boolean> {
  // Paymongo-Signature: t=timestamp,te=test_hmac,li=live_hmac
  const parts: Record<string, string> = {};
  for (const piece of header.split(",")) {
    const [k, ...rest] = piece.trim().split("=");
    if (!k || rest.length === 0) continue;
    parts[k.trim()] = rest.join("=").trim();
  }
  const timestamp = parts.t;
  const testSig = parts.te;
  const liveSig = parts.li;
  if (!timestamp || (!testSig && !liveSig)) return false;

  const signed = `${timestamp}.${raw}`;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signed),
  );
  const digest = hex(new Uint8Array(mac));
  return timingSafeEqual(digest, testSig) || timingSafeEqual(digest, liveSig);
}

function hex(bytes: Uint8Array): string {
  return [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
}

function timingSafeEqual(a: string, b: string | undefined): boolean {
  if (!b || a.length !== b.length) return false;
  let out = 0;
  for (let i = 0; i < a.length; i++) {
    out |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }
  return out === 0;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
