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

## After SQL

- Confirm columns: `transaction_items.refunded_quantity`, `transactions.refunded_total`, `stores.business_tin`, `cash_sessions.claimed_by`, `profiles.is_platform_admin`, `stores.suspended_at`
- Deploy `supabase/functions/delete-account`
- Promote your email with Script C helper
- Mark these filenames applied in your migration history if you use CLI later (`supabase migration repair` as needed)
