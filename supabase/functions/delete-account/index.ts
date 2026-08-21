// Deletes the signed-in user's Auth account after DB purge.
// Requires SUPABASE_SERVICE_ROLE_KEY (auto on hosted Supabase).

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

    const admin = createClient(supabaseUrl, serviceKey);

    const { data: purged, error: purgeErr } = await admin.rpc(
      "purge_account_data",
      { p_user_id: user.id },
    );
    if (purgeErr) {
      return json({
        error: "PURGE_FAILED",
        message: purgeErr.message,
      }, 500);
    }

    const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
    if (delErr) {
      return json({ error: "DELETE_FAILED", message: delErr.message }, 500);
    }

    return json({ ok: true, purged });
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
