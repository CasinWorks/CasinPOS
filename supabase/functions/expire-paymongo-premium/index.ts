// Daily expire of PayMongo Premium (Apple / Play / manual untouched).
// Invoke with Authorization: Bearer <BILLING_CRON_SECRET>
// or schedule via Supabase cron / an external ping.

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const corsHeaders: Record<string, string> = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS, GET",
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    if (req.method !== "POST" && req.method !== "GET") {
      return json({ error: "METHOD_NOT_ALLOWED" }, 405);
    }

    const expected = (Deno.env.get("BILLING_CRON_SECRET") ?? "").trim();
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

    const admin = createClient(supabaseUrl, serviceKey);
    const { data, error } = await admin.rpc("expire_stale_paymongo_premium");
    if (error) {
      return json({ error: "EXPIRE_FAILED", message: error.message }, 500);
    }

    return json({ ok: true, expired: data ?? 0 });
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
