// Deletes the signed-in user's Auth account after soft cleanup.
// Requires SUPABASE_SERVICE_ROLE_KEY (auto on hosted Supabase).

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

    const admin = createClient(supabaseUrl, serviceKey);

    // Soft cleanup first (memberships / PII).
    await userClient.rpc("request_account_deletion");

    // Own stores where this user is the only owner: delete store cascade.
    const { data: ownerships } = await admin
      .from("store_members")
      .select("store_id, role")
      .eq("user_id", user.id)
      .eq("status", "active")
      .eq("role", "owner");

    for (const row of ownerships ?? []) {
      const storeId = row.store_id as string;
      const { count } = await admin
        .from("store_members")
        .select("id", { count: "exact", head: true })
        .eq("store_id", storeId)
        .eq("status", "active")
        .eq("role", "owner");
      if ((count ?? 0) <= 1) {
        await admin.from("stores").delete().eq("id", storeId);
      } else {
        await admin
          .from("store_members")
          .update({ status: "removed" })
          .eq("store_id", storeId)
          .eq("user_id", user.id);
      }
    }

    const { error: delErr } = await admin.auth.admin.deleteUser(user.id);
    if (delErr) {
      return json({ error: "DELETE_FAILED", message: delErr.message }, 500);
    }

    return json({ ok: true });
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
