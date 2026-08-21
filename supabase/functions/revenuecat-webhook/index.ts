// RevenueCat server webhook → stores.plan_tier + subscriptions.
// Secrets: SUPABASE_SERVICE_ROLE_KEY (auto), REVENUECAT_WEBHOOK_SECRET
// Dashboard: Project → Integrations → Webhooks →
//   URL https://<project>.supabase.co/functions/v1/revenuecat-webhook
//   Authorization: Bearer <REVENUECAT_WEBHOOK_SECRET>

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PREMIUM_PRODUCT_IDS = new Set([
  "casinpos_premium_monthly",
]);

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST") {
      return json({ error: "METHOD_NOT_ALLOWED" }, 405);
    }

    const expected = (Deno.env.get("REVENUECAT_WEBHOOK_SECRET") ?? "").trim();
    const auth = req.headers.get("Authorization") ?? "";
    const token = auth.replace(/^Bearer\s+/i, "").trim();
    if (!expected || token !== expected) {
      return json({ error: "UNAUTHORIZED" }, 401);
    }

    const supabaseUrl = Deno.env.get("SUPABASE_URL") ?? "";
    const serviceKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
    if (!supabaseUrl || !serviceKey) {
      return json({ error: "SERVER_MISCONFIGURED" }, 500);
    }

    const body = await req.json() as {
      event?: {
        type?: string;
        app_user_id?: string;
        original_app_user_id?: string;
        product_id?: string;
        entitlement_ids?: string[] | null;
        expiration_at_ms?: number | null;
        purchased_at_ms?: number | null;
        store?: string;
        subscriber_attributes?: Record<string, { value?: string }>;
      };
    };

    const event = body.event;
    if (!event?.type) return json({ error: "NO_EVENT" }, 400);

    const appUserId = (event.app_user_id ?? event.original_app_user_id ?? "")
      .trim();
    if (!appUserId || appUserId.startsWith("$RCAnonymousID")) {
      return json({ ok: true, skipped: "anonymous_user" });
    }

    const admin = createClient(supabaseUrl, serviceKey);
    const storeId = await resolveStoreId(admin, appUserId, event);
    if (!storeId) {
      return json({ ok: true, skipped: "store_not_found", app_user_id: appUserId });
    }

    const type = event.type;
    const entitlements = event.entitlement_ids ?? [];
    const productId = event.product_id ?? "";
    const looksPremium =
      entitlements.includes("premium") ||
      PREMIUM_PRODUCT_IDS.has(productId);

    const deactivateTypes = new Set([
      "EXPIRATION",
      "SUBSCRIPTION_PAUSED",
    ]);
    // Billing issues: keep premium until EXPIRATION unless you prefer past_due.
    const activateTypes = new Set([
      "INITIAL_PURCHASE",
      "RENEWAL",
      "UNCANCELLATION",
      "PRODUCT_CHANGE",
      "NON_RENEWING_PURCHASE",
      "SUBSCRIPTION_EXTENDED",
      "TEMPORARY_ENTITLEMENT_GRANT",
    ]);

    let plan: "free" | "premium" = "free";
    let status: "active" | "past_due" | "canceled" = "canceled";

    if (activateTypes.has(type) && looksPremium) {
      plan = "premium";
      status = "active";
    } else if (type === "BILLING_ISSUE" && looksPremium) {
      plan = "premium";
      status = "past_due";
    } else if (type === "CANCELLATION" && looksPremium) {
      // User turned off auto-renew — keep Premium until Apple expiration.
      plan = "premium";
      status = "canceled";
    } else if (deactivateTypes.has(type)) {
      plan = "free";
      status = "canceled";
    } else if (type === "TRANSFER" || type === "TEST") {
      // Re-check would need RC REST; treat TEST + premium product as activate.
      if (looksPremium) {
        plan = "premium";
        status = "active";
      } else {
        return json({ ok: true, skipped: "unhandled", type });
      }
    } else {
      return json({ ok: true, skipped: "unhandled", type });
    }

    const periodStart = event.purchased_at_ms
      ? new Date(event.purchased_at_ms).toISOString()
      : null;
    const periodEnd = event.expiration_at_ms
      ? new Date(event.expiration_at_ms).toISOString()
      : null;

    const { data, error } = await admin.rpc(
      "apply_store_subscription_from_provider",
      {
        p_store_id: storeId,
        p_plan_tier: plan,
        p_status: status,
        p_provider: "revenuecat",
        p_provider_customer_id: appUserId,
        p_provider_subscription_id: productId || null,
        p_period_start: periodStart,
        p_period_end: periodEnd,
        p_monthly_limit: plan === "premium" ? 100000 : 1000,
      },
    );
    if (error) {
      return json({ error: "APPLY_FAILED", message: error.message }, 500);
    }

    return json({ ok: true, store_id: storeId, plan_tier: plan, status, data });
  } catch (e) {
    return json({ error: "UNEXPECTED", message: String(e) }, 500);
  }
});

async function resolveStoreId(
  admin: ReturnType<typeof createClient>,
  appUserId: string,
  event: {
    subscriber_attributes?: Record<string, { value?: string }>;
  },
): Promise<string | null> {
  const attr =
    event.subscriber_attributes?.store_id?.value?.trim() ||
    event.subscriber_attributes?.["store_id"]?.value?.trim();
  if (attr) return attr;

  const { data } = await admin
    .from("store_members")
    .select("store_id")
    .eq("user_id", appUserId)
    .eq("role", "owner")
    .eq("status", "active")
    .order("created_at", { ascending: true })
    .limit(1)
    .maybeSingle();
  return (data?.store_id as string | undefined) ?? null;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
