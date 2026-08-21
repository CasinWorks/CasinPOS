-- Apply store plan from an external billing provider (RevenueCat / Apple IAP).
-- Callable only by service_role (Edge Functions). Platform Ops remains manual.

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
begin
  if p_store_id is null then
    raise exception 'STORE_REQUIRED' using errcode = 'P0001';
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
    coalesce(nullif(trim(p_provider), ''), 'revenuecat'),
    p_provider_customer_id,
    p_provider_subscription_id,
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
    'provider', coalesce(nullif(trim(p_provider), ''), 'revenuecat'),
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
