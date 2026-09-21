// Owner-only: create a PayMongo Checkout Session for lifetime CasinPOS Premium.
// Fixed PH price: ₱199 (override with PAYMONGO_PREMIUM_PHP pesos, e.g. 199).
// Secrets: PAYMONGO_SECRET_KEY, optional PAYMONGO_PREMIUM_PHP

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const DEFAULT_PHP_PESOS = 199;
const APP_STORE_PROVIDERS = new Set(["revenuecat", "app_store", "play_store"]);
const LIFETIME_END = "2099-12-31T23:59:59.000Z";

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
    const paymongoSecret = (Deno.env.get("PAYMONGO_SECRET_KEY") ?? "").trim();
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

    const body = await req.json() as {
      store_id?: string;
      origin?: string;
      preview?: boolean;
      source?: string;
    };
    const storeId = (body.store_id ?? "").trim();
    if (!storeId) return json({ error: "STORE_REQUIRED" }, 400);
    const preview = body.preview === true;
    const webRegistration = (body.source ?? "").trim() === "web_registration";

    const admin = createClient(supabaseUrl, serviceKey);

    await admin.rpc("expire_stale_paymongo_premium");

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

    const { data: store } = await admin
      .from("stores")
      .select("id, name, plan_tier")
      .eq("id", storeId)
      .maybeSingle();
    if (!store) return json({ error: "STORE_NOT_FOUND" }, 404);

    const { data: sub } = await admin
      .from("subscriptions")
      .select("provider, status, plan_tier, current_period_end")
      .eq("store_id", storeId)
      .maybeSingle();

    const provider = (sub?.provider as string | undefined) ?? "manual";
    const periodEnd = Date.parse(String(sub?.current_period_end ?? ""));
    const stillCovered = !Number.isNaN(periodEnd) && periodEnd > Date.now();
    if (store.plan_tier === "premium" && stillCovered) {
      if (APP_STORE_PROVIDERS.has(provider)) {
        return json({
          error: "BILLED_VIA_APP_STORE",
          message:
            "This store is already billed through the iPhone or Android app. " +
            "Manage Premium there — don’t pay again on the web.",
        }, 409);
      }
      return json({
        error: "ALREADY_PREMIUM",
        message:
          "This store already has Premium unlocked. You don’t need to pay again.",
      }, 409);
    }

    const quote = premiumPhpQuote();
    if (preview) {
      return json({
        ok: true,
        preview: true,
        php_pesos: quote.pesos,
        amount_centavos: quote.centavos,
        amount_label: formatPhp(quote.centavos),
        store_id: storeId,
        source: webRegistration ? "web_registration" : "premium",
        // Legacy fields kept for older clients.
        usd: 0,
        fx_rate: 0,
      });
    }

    if (!paymongoSecret) {
      return json({
        error: "PAYMONGO_NOT_CONFIGURED",
        message: "PayMongo is not set up yet. Ask CasinPOS to add the secret key.",
      }, 503);
    }

    const amount = quote.centavos;
    const origin = sanitizeOrigin(body.origin) ??
      "https://pos.casinworks.com";
    const successUrl = webRegistration
      ? `${origin}/onboarding/activate?premium=success`
      : `${origin}/?premium=success`;
    const cancelUrl = webRegistration
      ? `${origin}/onboarding/activate?premium=cancel`
      : `${origin}/?premium=cancel`;

    const productName = webRegistration
      ? "CasinPOS web registration"
      : "CasinPOS Premium Lifetime";
    const description = webRegistration
      ? `CasinPOS web registration (${formatPhp(amount)} one-time)`
      : `CasinPOS Premium Lifetime (${formatPhp(amount)} one-time)`;

    const pmRes = await fetch("https://api.paymongo.com/v1/checkout_sessions", {
      method: "POST",
      headers: {
        Authorization: paymongoBasic(paymongoSecret),
        "Content-Type": "application/json",
        Accept: "application/json",
      },
      body: JSON.stringify({
        data: {
          attributes: {
            send_email_receipt: true,
            show_description: true,
            show_line_items: true,
            description,
            line_items: [
              {
                currency: "PHP",
                amount,
                name: productName,
                quantity: 1,
              },
            ],
            payment_method_types: ["qrph", "gcash", "paymaya", "card"],
            success_url: successUrl,
            cancel_url: cancelUrl,
            metadata: {
              store_id: storeId,
              product: webRegistration
                ? "casinpos_web_registration"
                : "casinpos_premium_lifetime",
              source: webRegistration ? "web_registration" : "premium",
              php_pesos: String(quote.pesos),
              period_end: LIFETIME_END,
            },
          },
        },
      }),
    });

    const pmJson = await pmRes.json() as {
      data?: {
        id?: string;
        attributes?: { checkout_url?: string };
      };
      errors?: Array<{ detail?: string; code?: string }>;
    };

    if (!pmRes.ok || !pmJson.data?.id || !pmJson.data.attributes?.checkout_url) {
      const detail = pmJson.errors?.[0]?.detail ?? "PayMongo checkout failed";
      return json({ error: "CHECKOUT_FAILED", message: detail }, 502);
    }

    const checkoutId = pmJson.data.id;
    const checkoutUrl = pmJson.data.attributes.checkout_url;

    const { error: insertErr } = await admin.from("billing_checkout_sessions")
      .insert({
        store_id: storeId,
        created_by: user.id,
        paymongo_checkout_id: checkoutId,
        status: "pending",
        amount_centavos: amount,
      });
    if (insertErr) {
      return json({ error: "SESSION_SAVE_FAILED", message: insertErr.message }, 500);
    }

    return json({
      ok: true,
      checkout_id: checkoutId,
      checkout_url: checkoutUrl,
      amount_centavos: amount,
      amount_label: formatPhp(amount),
      php_pesos: quote.pesos,
      store_id: storeId,
      usd: 0,
      fx_rate: 0,
    });
  } catch (e) {
    return json({ error: "UNEXPECTED", message: String(e) }, 500);
  }
});

function parsePhpPesos(): number {
  const n = Number.parseFloat((Deno.env.get("PAYMONGO_PREMIUM_PHP") ?? "").trim());
  if (!Number.isFinite(n) || n < 1) return DEFAULT_PHP_PESOS;
  return Math.round(n * 100) / 100;
}

function premiumPhpQuote(): { pesos: number; centavos: number } {
  const pesos = parsePhpPesos();
  const centavos = Math.max(100, Math.round(pesos * 100));
  return { pesos, centavos };
}

function paymongoBasic(secret: string): string {
  return `Basic ${btoa(`${secret}:`)}`;
}

function sanitizeOrigin(raw: string | undefined): string | null {
  const s = (raw ?? "").trim().replace(/\/+$/, "");
  if (!s) return null;
  try {
    const u = new URL(s);
    if (u.protocol !== "https:" && u.protocol !== "http:") return null;
    return `${u.protocol}//${u.host}`;
  } catch {
    return null;
  }
}

function formatPhp(centavos: number): string {
  const pesos = centavos / 100;
  return `₱${pesos.toFixed(pesos % 1 === 0 ? 0 : 2)}`;
}

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}
