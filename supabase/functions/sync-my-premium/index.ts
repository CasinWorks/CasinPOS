// After StoreKit purchase/restore, client calls this to apply Premium immediately
// (webhook remains source of truth for renewals / expiry).
// Secrets: SUPABASE_SERVICE_ROLE_KEY (auto), REVENUECAT_SECRET_API_KEY
//
// One Apple subscription (store_transaction_id) unlocks exactly one CasinPOS store.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const PREMIUM_PRODUCT = "casinpos_premium_monthly";

type RcSub = {
  expires_date?: string | null;
  purchase_date?: string | null;
  original_purchase_date?: string | null;
  unsubscribe_detected_at?: string | null;
  store_transaction_id?: string | null;
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

    let lastPayload: unknown = null;
    let active = false;
    let productId = PREMIUM_PRODUCT;
    let periodStart: string | null = null;
    let periodEnd: string | null = null;
    let bindId: string | null = null;

    for (let attempt = 0; attempt < 4; attempt++) {
      if (attempt > 0) {
        await new Promise((r) => setTimeout(r, 800 * attempt));
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
        lastPayload = { status: rcRes.status, text: text.slice(0, 400) };
        continue;
      }

      const payload = await rcRes.json() as {
        subscriber?: {
          entitlements?: Record<string, {
            expires_date?: string | null;
            product_identifier?: string;
          }>;
          subscriptions?: Record<string, RcSub>;
        };
      };
      lastPayload = payload;

      const ents = payload.subscriber?.entitlements ?? {};
      let premium = ents["premium"];
      if (!premium) {
        for (const ent of Object.values(ents)) {
          if (ent.product_identifier === PREMIUM_PRODUCT) {
            premium = ent;
            break;
          }
        }
      }

      const sub =
        payload.subscriber?.subscriptions?.[PREMIUM_PRODUCT] ??
        (premium?.product_identifier
          ? payload.subscriber?.subscriptions?.[premium.product_identifier]
          : undefined);

      const expiresRaw = premium?.expires_date ?? sub?.expires_date ?? null;
      const expires = expiresRaw ? Date.parse(expiresRaw) : null;
      const entActive = !!premium &&
        (expires == null || Number.isNaN(expires) || expires > Date.now());
      const subActive = !!sub &&
        (sub.expires_date == null ||
          Date.parse(sub.expires_date) > Date.now());

      if (entActive || subActive) {
        active = true;
        productId = premium?.product_identifier ?? PREMIUM_PRODUCT;
        periodStart = sub?.purchase_date ?? null;
        periodEnd = expiresRaw;
        // Prefer Apple/Play transaction id so one phone sub ≠ many stores.
        bindId = (sub?.store_transaction_id ?? "").trim() ||
          (sub?.original_purchase_date
            ? `${productId}:${sub.original_purchase_date}`
            : null);
        break;
      }
    }

    if (!active) {
      return json({
        ok: false,
        error: "NO_ACTIVE_PREMIUM",
        message:
          "Purchase received, but Premium is not active on RevenueCat yet. Tap Restore in a moment.",
        debug: lastPayload,
      }, 402);
    }

    if (!bindId) {
      // Fallback: still apply, but cannot enforce cross-store bind without a tx id.
      bindId = `${productId}:user:${user.id}`;
    }

    // Fast path message if already bound elsewhere (RPC also enforces).
    const { data: boundRows } = await admin
      .from("subscriptions")
      .select("store_id")
      .eq("provider", "revenuecat")
      .eq("provider_subscription_id", bindId)
      .eq("status", "active")
      .neq("store_id", storeId)
      .limit(1);

    const boundStoreId =
      Array.isArray(boundRows) && boundRows.length > 0
        ? (boundRows[0] as { store_id: string }).store_id
        : null;

    if (boundStoreId) {
      const { data: otherStore } = await admin
        .from("stores")
        .select("name")
        .eq("id", boundStoreId)
        .maybeSingle();
      const otherName = (otherStore?.name as string | undefined) ?? "another store";
      return json({
        ok: false,
        error: "SUBSCRIPTION_BOUND_TO_OTHER_STORE",
        message:
          `This Apple subscription already unlocks “${otherName}”. ` +
          `One Apple ID Premium unlocks one CasinPOS store. ` +
          `Sign into that store, or set it Free in Platform Ops before moving Premium here.`,
        other_store_id: boundStoreId,
        other_store_name: otherName,
      }, 409);
    }

    const { data, error } = await admin.rpc(
      "apply_store_subscription_from_provider",
      {
        p_store_id: storeId,
        p_plan_tier: "premium",
        p_status: "active",
        p_provider: "revenuecat",
        p_provider_customer_id: user.id,
        p_provider_subscription_id: bindId,
        p_period_start: periodStart,
        p_period_end: periodEnd,
        p_monthly_limit: 100000,
      },
    );
    if (error) {
      const msg = error.message ?? "";
      const detail = (error as { details?: string }).details ?? "";
      if (msg.includes("SUBSCRIPTION_BOUND_TO_OTHER_STORE")) {
        return json({
          ok: false,
          error: "SUBSCRIPTION_BOUND_TO_OTHER_STORE",
          message:
            `This Apple subscription already unlocks “${detail || "another store"}”. ` +
            `One Apple ID Premium unlocks one CasinPOS store.`,
        }, 409);
      }
      return json({ error: "APPLY_FAILED", message: error.message }, 500);
    }

    return json({ ok: true, store_id: storeId, data });
  } catch (e) {
    return new Response(JSON.stringify({ error: "UNEXPECTED", message: String(e) }), {
      status: 500,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
