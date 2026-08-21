// Creates a pending store invite via RPC using the caller's JWT.
// Exists so the Flutter web client can POST /functions/v1/... instead of
// hitting PostgREST /rpc/create_store_invitation (Safari was 404ing that RPC).

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
    if (!supabaseUrl || !anonKey) {
      return json({ error: "SERVER_MISCONFIGURED" }, 500);
    }

    const authHeader = req.headers.get("Authorization");
    if (!authHeader) {
      return json({ error: "NOT_AUTHENTICATED" }, 401);
    }

    const userClient = createClient(supabaseUrl, anonKey, {
      global: { headers: { Authorization: authHeader } },
    });

    const body = await req.json() as {
      store_id?: string;
      email?: string;
      role?: string;
      branch_ids?: string[] | null;
    };

    const storeId = (body.store_id ?? "").trim();
    const email = (body.email ?? "").trim().toLowerCase();
    const role = (body.role ?? "staff").trim();
    const branchIds = Array.isArray(body.branch_ids) && body.branch_ids.length > 0
      ? body.branch_ids
      : null;

    if (!storeId || !email) {
      return json({ error: "STORE_AND_EMAIL_REQUIRED" }, 400);
    }

    const params: Record<string, unknown> = {
      p_store_id: storeId,
      p_email: email,
      p_role: role,
    };
    if (branchIds != null) params.p_branch_ids = branchIds;

    const { data, error } = await userClient.rpc(
      "create_store_invitation",
      params,
    );

    if (error) {
      const msg = error.message || error.code || "Could not send invite";
      const status = /not_authenticated/i.test(msg)
        ? 401
        : /forbidden|cannot_invite|already_a_member|email_invalid|seat/i.test(
            msg,
          )
        ? 400
        : 400;
      return json({ error: msg, details: error.details, code: error.code }, status);
    }

    return json(data ?? { error: "EMPTY_RESPONSE" }, data ? 200 : 500);
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
