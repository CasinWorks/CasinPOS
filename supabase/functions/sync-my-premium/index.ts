// After StoreKit purchase/restore, client calls this to apply Premium immediately
// (webhook remains source of truth for renewals / expiry).
// Secrets: SUPABASE_SERVICE_ROLE_KEY (auto), REVENUECAT_SECRET_API_KEY

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
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
    const rcSecret = (Deno.env.get("REVENUECAT_SECRET_API_KEY") ?? "").trim();
    if (!supabaseUrl || !anonKey || !serviceKey || !rcSecret) {
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

    const body = await req.json() as { store_id?: string };
    const storeId = (body.store_id ?? "").trim();
    if (!storeId) return json({ error: "STORE_REQUIRED" }, 400);

    const admin = createClient(supabaseUrl, serviceKey);
    const { data: membership } = await admin
      .from("store_members")
      .select("role, status")
      .eq("store_id", storeId)
      .eq("user_id", user.id)
      .maybeSingle();

    if (
      !membership ||
      membership.status !== "active" ||
      membership.role !== "owner"
    ) {
      return json({ error: "FORBIDDEN" }, 403);
    }

    const rcRes = await fetch(
      `https://api.revenuecat.com/v1/subscribers/${encodeURIComponent(user.id)}`,
      {
        headers: {
          Authorization: `Bearer ${rcSecret}`,
          "Content-Type": "application/json",
        },
      },
    );
    if (!rcRes.ok) {
      const text = await rcRes.text();
      return json({
        error: "REVENUECAT_LOOKUP_FAILED",
        message: text.slice(0, 400),
      }, 502);
    }

    const payload = await rcRes.json() as {
      subscriber?: {
        entitlements?: Record<string, {
          expires_date?: string | null;
          product_identifier?: string;
        }>;
        subscriptions?: Record<string, {
          expires_date?: string | null;
          purchase_date?: string | null;
        }>;
      };
    };

    const premium = payload.subscriber?.entitlements?.premium;
    const expires = premium?.expires_date
      ? Date.parse(premium.expires_date)
      : null;
    const active = !!premium &&
      (expires == null || Number.isNaN(expires) || expires > Date.now());

    if (!active) {
      return json({
        ok: false,
        error: "NO_ACTIVE_PREMIUM",
        message: "No active Premium entitlement found for this Apple ID.",
      }, 402);
    }

    const productId = premium?.product_identifier ?? "casinpos_premium_monthly";
    const sub = payload.subscriber?.subscriptions?.[productId];

    const { data, error } = await admin.rpc(
      "apply_store_subscription_from_provider",
      {
        p_store_id: storeId,
        p_plan_tier: "premium",
        p_status: "active",
        p_provider: "revenuecat",
        p_provider_customer_id: user.id,
        p_provider_subscription_id: productId,
        p_period_start: sub?.purchase_date ?? null,
        p_period_end: premium?.expires_date ?? sub?.expires_date ?? null,
        p_monthly_limit: 100000,
      },
    );
    if (error) {
      return json({ error: "APPLY_FAILED", message: error.message }, 500);
    }

    return json({ ok: true, store_id: storeId, data });
  } catch (e) {
    return json({ error: "UNEXPECTED", message: String(e) }, 500);
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
