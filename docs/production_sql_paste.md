# Production SQL — paste in Supabase SQL Editor

Project linked historically as FoodPOS (`ftbmkqpioyfzrkziptox`).

1. Open Supabase Dashboard → **SQL** → New query  
2. Paste **Script A**, Run  
3. Paste **Script B**, Run  
4. Deploy Edge Function `delete-account` (CLI: `supabase functions deploy delete-account`)

---

## Script A — Refunds (`20260810000100`)

```sql
alter table public.transaction_items
  add column if not exists refunded_quantity numeric(12, 3) not null default 0;

alter table public.transactions
  add column if not exists refunded_total numeric(12, 2) not null default 0;

create or replace function public.on_transaction_voided()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = 'paid'
     and new.status in ('voided', 'refunded') then
    update public.stores
    set
      transactions_this_period = greatest(0, transactions_this_period - 1),
      updated_at = now()
    where id = new.store_id;
  end if;
  return new;
end;
$$;
```

---

## Script B — Account delete + receipt TIN/address + shift claim (`20260810000200`)

```sql
alter table public.stores
  add column if not exists business_tin text,
  add column if not exists business_address text;

alter table public.cash_sessions
  add column if not exists claimed_by uuid references public.profiles (id),
  add column if not exists claimed_at timestamptz;

create or replace function public.request_account_deletion()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owned int;
begin
  if v_uid is null then
    raise exception 'Not signed in';
  end if;

  select count(*) into v_owned
  from public.store_members
  where user_id = v_uid
    and status = 'active'
    and role = 'owner';

  update public.store_members
  set status = 'removed', updated_at = now()
  where user_id = v_uid
    and status = 'active'
    and role <> 'owner';

  update public.profiles
  set
    full_name = 'Deleted User',
    avatar_url = null,
    phone = null,
    onboarding_completed = true,
    updated_at = now()
  where id = v_uid;

  return jsonb_build_object(
    'ok', true,
    'owned_stores', v_owned,
    'message', case
      when v_owned > 0 then
        'Account marked for deletion. Ownership of stores will be cleared by the delete-account function.'
      else
        'Account marked for deletion.'
    end
  );
end;
$$;

grant execute on function public.request_account_deletion() to authenticated;
```

---

## Script C — Platform Ops (`20260811000100`)

Paste the full contents of:

`supabase/migrations/20260811000100_platform_ops.sql`

Or if you already applied A/B, run that migration file next.

### Promote yourself as platform admin

After Script C, run (replace the email):

```sql
select public.platform_set_admin_by_email('YOUR_EMAIL@casinworks.com', true);
```

Then sign out / sign in. Sidebar → **Platform Ops**.

### Ops actions available
- Search all customer stores
- Set Free / Premium (+ monthly limit)
- Suspend / reinstate (blocks sales via `STORE_SUSPENDED`)

---

## Script D — Free seats + 100 txns (`20260811000200`)

Paste the full contents of:

`supabase/migrations/20260811000200_free_plan_seats_and_100_txns.sql`

Effects:
- Free monthly paid sales default **100** (existing free stores on 50 are bumped to 100)
- Free team seats = **2** (owner + 1 teammate); invite/accept blocked beyond that

---

## Script E — Team manage (`20260811000300`)

Paste the full contents of:

`supabase/migrations/20260811000300_team_manage.sql`

Effects:
- `list_store_team` — members + pending invites (Owner/Admin)
- `update_store_member_role` — change role (guards: no owner assign / self / admin-vs-admin)
- `remove_store_member` — soft-disable member (frees Free seats)
- `revoke_store_invitation` — cancel pending invite

---

## After SQL

- Confirm columns: `transaction_items.refunded_quantity`, `transactions.refunded_total`, `stores.business_tin`, `cash_sessions.claimed_by`, `profiles.is_platform_admin`, `stores.suspended_at`
- Deploy `supabase/functions/delete-account`
- Promote your email with Script C helper
- Apply Script D for Free plan seat + 100 txns limits
- Apply Script E for Team manage RPCs
- Apply Script F (+ F2 if PIN crypt fails) for Cashier PIN
- Apply Script G for Platform Ops depth; deploy `platform-reset-password`
- Mark these filenames applied in your migration history if you use CLI later (`supabase migration repair` as needed)
- Auth: paste recovery email template + allow-list `/reset-password` redirect URL

---

## Script F — Cashier PIN (`20260812000100`)

Paste the full contents of:

`supabase/migrations/20260812000100_cashier_pins.sql`

Effects:
- Private `store_member_pins` table (bcrypt via pgcrypto; no client read)
- `set_my_store_pin` / `admin_clear_member_pin` / `verify_member_pin` / `claim_shift_with_pin`
- `list_shift_roster` + `has_pin` on team list
- Lockout after 5 wrong attempts (5 minutes)

---

## Script F2 — PIN pgcrypto path fix (`20260812000200`)

If **Set my PIN** fails after Script F, paste:

`supabase/migrations/20260812000200_cashier_pin_pgcrypto_path.sql`

Supabase keeps `crypt` / `gen_salt` in the `extensions` schema; this updates PIN RPCs to include it on `search_path`.

---

## Script G — Platform Ops depth (`20260813000100`)

Paste the full contents of:

`supabase/migrations/20260813000100_platform_ops_depth.sql`

Effects:
- `platform_support_notes` + `platform_list_support_notes` / `platform_add_support_note`
- `store_messages` + `store_message_reads` + send/list/mark-read RPCs
- `platform_admin_audit` + `platform_log_audit`
- Tenants see messages under sidebar **Notifications**

Then deploy:

```bash
supabase functions deploy platform-reset-password
```

Optional secrets (same as invites): `RESEND_API_KEY`, `RESEND_FROM_EMAIL`, `PUBLIC_APP_URL`.
Without Resend, ops UI copies the recovery link when reset is triggered.

---

## Script H — Products RLS fix (`20260814000100`)

If **Add / edit product** fails with `42501` / row-level security on `products`, paste:

`supabase/migrations/20260814000100_products_rls_fix.sql`

Effects:
- Replaces brittle `FOR ALL` write policies on `products` and `categories`
- Explicit INSERT / UPDATE / DELETE with `WITH CHECK`
- Any **active store member** can manage inventory (retail day-to-day)

---

## Script I — Product images storage (`20260814000200`)

If **photo upload** fails with Storage `403` / row-level security, paste:

`supabase/migrations/20260814000200_product_images_storage_fix.sql`

Effects:
- Creates public `product-images` bucket (5 MB, jpeg/png/webp/gif) if missing
- Storage INSERT/UPDATE/DELETE allowed for active members of that store
- Paths must be `{store_id}/{product_id}/filename`

---

## Script J — Product sales + discount codes (`20260815000100`)

Paste:

`supabase/migrations/20260815000100_product_sales_and_discount_codes.sql`

Effects:
- `products.sale_price` / `sale_starts_at` / `sale_ends_at` for timed product sales
- `discount_codes` table (percent or fixed ₱) with Owner/Admin write RLS
- `transactions.discount_code` / `discount_amount` for checkout audit

---

## Script K — Receipt TIN/address + store update RLS (`20260816000100`)

If **Store settings → TIN / business address** won’t save (or receipts stay blank), paste:

```sql
alter table public.stores
  add column if not exists business_tin text,
  add column if not exists business_address text;

comment on column public.stores.business_tin is 'BIR TIN shown on receipts';
comment on column public.stores.business_address is 'Business address shown on receipts';

drop policy if exists stores_update_owner_admin on public.stores;
create policy stores_update_owner_admin on public.stores
  for update
  using (
    public.has_store_role(id, array['owner', 'admin']::public.store_role[])
  )
  with check (
    public.has_store_role(id, array['owner', 'admin']::public.store_role[])
  );
```

Effects:
- Ensures `stores.business_tin` / `business_address` exist
- Owner/Admin can UPDATE stores with explicit `WITH CHECK` (needed for save + reload)

---

## Script L — Free plan 1,000 txns/month (`20260817000100`)

Paste:

```sql
alter table public.stores
  alter column monthly_transaction_limit set default 1000;

update public.stores
set
  monthly_transaction_limit = 1000,
  updated_at = now()
where plan_tier = 'free'
  and monthly_transaction_limit in (50, 100);

create or replace function public.platform_set_store_plan(
  p_store_id uuid,
  p_plan_tier public.plan_tier,
  p_monthly_limit int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit int;
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  if not exists (select 1 from public.stores where id = p_store_id) then
    raise exception 'STORE_NOT_FOUND' using errcode = 'P0001';
  end if;

  v_limit := coalesce(
    p_monthly_limit,
    case when p_plan_tier = 'premium' then 100000 else 1000 end
  );

  update public.stores
  set
    plan_tier = p_plan_tier,
    monthly_transaction_limit = greatest(1, v_limit),
    updated_at = now()
  where id = p_store_id;

  update public.subscriptions
  set
    plan_tier = p_plan_tier,
    status = 'active',
    provider = 'manual',
    updated_at = now()
  where store_id = p_store_id;

  return jsonb_build_object(
    'ok', true,
    'store_id', p_store_id,
    'plan_tier', p_plan_tier,
    'monthly_transaction_limit', v_limit
  );
end;
$$;
```

Effects:
- New Free stores default to **1,000** paid sales/month
- Existing Free stores still on 50 or 100 are bumped to **1,000**
- Platform Ops “Set Free” default limit becomes 1,000

---

## Script M — Branch Manager + Reports (`20260818000100` + `20260818000200`)

**Run in two steps** (enum first, then rest):

1. Paste `supabase/migrations/20260818000100_branch_manager_role_enum.sql` → Run  
2. Paste `supabase/migrations/20260818000200_branch_manager_and_reports.sql` → Run  

If step 2 previously failed on `update_store_member_role` return type, re-run the **updated** file (it now `DROP`s the old `void` function first). Or paste this first, then re-run step 2:

```sql
drop function if exists public.update_store_member_role(uuid, public.store_role);
drop function if exists public.update_store_member_role(uuid, public.store_role, uuid[]);
```

Effects:
- Adds `branch_manager` role (scoped via `store_members.branch_ids`)
- Branch-scoped helpers + transaction SELECT RLS for branch managers
- Product `supplier_name` / `last_restocked_at` (COGS uses existing `cost_price`)
- RPCs: `list_store_branches`, `report_inventory`, `report_sales_lines`, `report_profitability`, `report_dashboard_stats`
