// Platform admin deletes a customer store (test cleanup).
// Requires caller JWT with profiles.is_platform_admin.
// Body: { store_id, confirm_name }
// When the owner has no other stores and is not a platform admin, also
// purge_account_data + auth.admin.deleteUser.

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

    const { data: adminOk, error: adminErr } = await userClient.rpc(
      "platform_assert_admin",
    );
    if (adminErr || adminOk !== true) {
      return json({ error: "FORBIDDEN", message: "Platform admin only." }, 403);
    }

    const body = await req.json() as {
      store_id?: string;
      confirm_name?: string;
    };
    const storeId = (body.store_id ?? "").trim();
    const confirmName = (body.confirm_name ?? "").trim();
    if (!storeId) return json({ error: "STORE_REQUIRED" }, 400);
    if (!confirmName) {
      return json({
        error: "CONFIRM_REQUIRED",
        message: "Type the exact store name to confirm deletion.",
      }, 400);
    }

    const { data: preview, error: previewErr } = await userClient.rpc(
      "platform_tenant_delete_preview",
      { p_store_id: storeId },
    );
    if (previewErr) {
      return json({
        error: "PREVIEW_FAILED",
        message: previewErr.message,
      }, 400);
    }

    const storeName = String((preview as { store_name?: string })?.store_name ?? "");
    const ownerId = String((preview as { owner_id?: string })?.owner_id ?? "");
    const ownerIsAdmin =
      (preview as { owner_is_platform_admin?: boolean })?.owner_is_platform_admin ===
        true;
    const willDeleteAuth =
      (preview as { will_delete_auth_user?: boolean })?.will_delete_auth_user ===
        true;

    if (storeName.trim().toLowerCase() !== confirmName.toLowerCase()) {
      return json({
        error: "NAME_MISMATCH",
        message: "Store name does not match. Type it exactly to confirm.",
      }, 400);
    }

    if (ownerId && ownerId === user.id) {
      return json({
        error: "CANNOT_DELETE_SELF",
        message: "You cannot delete your own admin account from Platform Ops.",
      }, 400);
    }

    if (ownerIsAdmin) {
      return json({
        error: "CANNOT_DELETE_ADMIN",
        message: "Refusing to delete a platform admin account.",
      }, 400);
    }

    const admin = createClient(supabaseUrl, serviceKey);

    // Soft-delete audit before hard delete (store may cascade).
    try {
      await admin.from("platform_admin_audit").insert({
        admin_id: user.id,
        action: "delete_tenant",
        store_id: storeId,
        target_user_id: ownerId || null,
        meta: {
          store_name: storeName,
          will_delete_auth_user: willDeleteAuth,
        },
      });
    } catch {
      // Audit table optional / RLS — continue.
    }

    const { error: delStoreErr } = await admin.from("stores").delete().eq(
      "id",
      storeId,
    );
    if (delStoreErr) {
      return json({
        error: "STORE_DELETE_FAILED",
        message: delStoreErr.message,
      }, 500);
    }

    let authDeleted = false;
    if (willDeleteAuth && ownerId) {
      const { error: purgeErr } = await admin.rpc("purge_account_data", {
        p_user_id: ownerId,
      });
      if (purgeErr) {
        return json({
          ok: true,
          store_deleted: true,
          auth_deleted: false,
          warning: `Store deleted but account purge failed: ${purgeErr.message}`,
        });
      }
      const { error: delUserErr } = await admin.auth.admin.deleteUser(ownerId);
      if (delUserErr) {
        return json({
          ok: true,
          store_deleted: true,
          auth_deleted: false,
          warning: `Store deleted but Auth user delete failed: ${delUserErr.message}`,
        });
      }
      authDeleted = true;
    }

    return json({
      ok: true,
      store_deleted: true,
      auth_deleted: authDeleted,
      store_id: storeId,
      store_name: storeName,
    });
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
