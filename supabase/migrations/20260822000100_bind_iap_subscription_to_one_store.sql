-- One Apple / RevenueCat subscription may unlock only one CasinPOS store.
-- apply_store_subscription_from_provider rejects (or optionally moves) if the
-- same provider_subscription_id is already active on another store.

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

  -- Bind: one store-facing Apple/RC subscription id → one store.
  if p_plan_tier = 'premium'
     and p_status = 'active'
     and v_provider in ('revenuecat', 'app_store', 'play_store')
     and v_sub_id is not null
     and v_sub_id not like 'casinpos_premium%' -- ignore legacy product-id-only keys
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
