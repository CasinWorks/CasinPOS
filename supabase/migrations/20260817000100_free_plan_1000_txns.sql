-- Free plan: raise monthly paid sales allowance from 100 → 1000.

alter table public.stores
  alter column monthly_transaction_limit set default 1000;

-- Existing free stores still on the old Free defaults (50 or 100).
-- Custom / ops overrides above 100 are left alone.
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
