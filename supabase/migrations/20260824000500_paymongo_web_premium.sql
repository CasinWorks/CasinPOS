-- PayMongo Checkout sessions for CasinPOS Premium on web.
-- Store POS payments are unchanged. iOS/Android stay on RevenueCat.

create table if not exists public.billing_checkout_sessions (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  created_by uuid references auth.users (id) on delete set null,
  paymongo_checkout_id text not null unique,
  status text not null default 'pending'
    check (status in ('pending', 'paid', 'expired', 'canceled')),
  amount_centavos int not null check (amount_centavos > 0),
  paymongo_payment_id text,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists billing_checkout_sessions_payment_uidx
  on public.billing_checkout_sessions (paymongo_payment_id)
  where paymongo_payment_id is not null;

create index if not exists billing_checkout_sessions_store_idx
  on public.billing_checkout_sessions (store_id, created_at desc);

alter table public.billing_checkout_sessions enable row level security;

drop policy if exists billing_checkout_sessions_select on public.billing_checkout_sessions;
create policy billing_checkout_sessions_select on public.billing_checkout_sessions
  for select using (public.is_store_member(store_id));

grant select on public.billing_checkout_sessions to authenticated;

-- Bind PayMongo payment ids the same way Apple transaction ids are bound.
create or replace function public.apply_store_subscription_from_provider(
  p_store_id uuid,
  p_plan_tier public.plan_tier,
  p_status public.subscription_status default 'active',
  p_provider text default 'revenuecat',
  p_provider_customer_id text default null,
  p_provider_subscription_id text default null,
  p_period_start timestamptz default null,
  p_period_end timestamptz default null,
  p_monthly_limit int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit int;
  v_provider text;
  v_sub_id text;
  v_other_store_id uuid;
  v_other_store_name text;
begin
  if p_store_id is null then
    raise exception 'STORE_REQUIRED' using errcode = 'P0001';
  end if;

  if not exists (select 1 from public.stores where id = p_store_id) then
    raise exception 'STORE_NOT_FOUND' using errcode = 'P0001';
  end if;

  v_provider := coalesce(nullif(trim(p_provider), ''), 'revenuecat');
  v_sub_id := nullif(trim(p_provider_subscription_id), '');
  v_limit := coalesce(
    p_monthly_limit,
    case when p_plan_tier = 'premium' then 100000 else 1000 end
  );

  if p_plan_tier = 'premium'
     and p_status = 'active'
     and v_provider in ('revenuecat', 'app_store', 'play_store', 'paymongo')
     and v_sub_id is not null
     and v_sub_id not like 'casinpos_premium%'
  then
    select s.id, s.name
      into v_other_store_id, v_other_store_name
    from public.subscriptions sub
    join public.stores s on s.id = sub.store_id
    where sub.store_id <> p_store_id
      and sub.provider = v_provider
      and sub.provider_subscription_id = v_sub_id
      and sub.status = 'active'
      and s.plan_tier = 'premium'
    limit 1;

    if v_other_store_id is not null then
      raise exception 'SUBSCRIPTION_BOUND_TO_OTHER_STORE'
        using errcode = 'P0001',
          detail = coalesce(v_other_store_name, v_other_store_id::text);
    end if;
  end if;

  update public.stores
  set
    plan_tier = p_plan_tier,
    monthly_transaction_limit = greatest(1, v_limit),
    updated_at = now()
  where id = p_store_id;

  insert into public.subscriptions as sub (
    store_id,
    plan_tier,
    status,
    provider,
    provider_customer_id,
    provider_subscription_id,
    current_period_start,
    current_period_end,
    updated_at
  )
  values (
    p_store_id,
    p_plan_tier,
    p_status,
    v_provider,
    p_provider_customer_id,
    v_sub_id,
    coalesce(p_period_start, date_trunc('month', now())),
    coalesce(p_period_end, date_trunc('month', now()) + interval '1 month'),
    now()
  )
  on conflict (store_id) do update set
    plan_tier = excluded.plan_tier,
    status = excluded.status,
    provider = excluded.provider,
    provider_customer_id = coalesce(
      excluded.provider_customer_id,
      sub.provider_customer_id
    ),
    provider_subscription_id = coalesce(
      excluded.provider_subscription_id,
      sub.provider_subscription_id
    ),
    current_period_start = coalesce(
      excluded.current_period_start,
      sub.current_period_start
    ),
    current_period_end = coalesce(
      excluded.current_period_end,
      sub.current_period_end
    ),
    updated_at = now();

  return jsonb_build_object(
    'ok', true,
    'store_id', p_store_id,
    'plan_tier', p_plan_tier,
    'status', p_status,
    'provider', v_provider,
    'monthly_transaction_limit', v_limit
  );
end;
$$;

revoke all on function public.apply_store_subscription_from_provider(
  uuid, public.plan_tier, public.subscription_status, text, text, text, timestamptz, timestamptz, int
) from public;
grant execute on function public.apply_store_subscription_from_provider(
  uuid, public.plan_tier, public.subscription_status, text, text, text, timestamptz, timestamptz, int
) to service_role;

-- Drop expired PayMongo Premium. Never touches Apple / Play / RevenueCat / manual.
create or replace function public.expire_stale_paymongo_premium()
returns int
language plpgsql
security definer
set search_path = public
as $$
declare
  n int := 0;
begin
  update public.stores s
  set
    plan_tier = 'free',
    monthly_transaction_limit = 1000,
    updated_at = now()
  from public.subscriptions sub
  where sub.store_id = s.id
    and sub.provider = 'paymongo'
    and s.plan_tier = 'premium'
    and sub.current_period_end < now();

  get diagnostics n = row_count;

  update public.subscriptions
  set
    plan_tier = 'free',
    status = 'canceled',
    updated_at = now()
  where provider = 'paymongo'
    and plan_tier = 'premium'
    and current_period_end < now();

  return n;
end;
$$;

revoke all on function public.expire_stale_paymongo_premium() from public;
grant execute on function public.expire_stale_paymongo_premium() to authenticated;
grant execute on function public.expire_stale_paymongo_premium() to service_role;

notify pgrst, 'reload schema';
