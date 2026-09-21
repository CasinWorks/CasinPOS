-- Web registration: create_store can leave a store unpaid until PayMongo ₱199.

drop function if exists public.create_store(
  text, public.business_type, text, text, text, public.service_pricing_mode
);

create function public.create_store(
  p_name text,
  p_business_type public.business_type,
  p_currency_code text default 'PHP',
  p_currency_symbol text default '₱',
  p_primary_branch_name text default 'Main',
  p_service_pricing_mode public.service_pricing_mode default null,
  p_pending_web_payment boolean default false
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_uid uuid := auth.uid();
  v_mode public.service_pricing_mode;
  v_pending boolean := coalesce(p_pending_web_payment, false);
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if length(trim(p_name)) < 1 then
    raise exception 'STORE_NAME_REQUIRED';
  end if;

  v_mode := case
    when p_business_type = 'service' then coalesce(p_service_pricing_mode, 'fixed')
    else null
  end;

  if v_pending then
    insert into public.stores (
      name,
      business_type,
      owner_id,
      currency_code,
      currency_symbol,
      service_pricing_mode,
      plan_tier,
      monthly_transaction_limit
    ) values (
      trim(p_name),
      p_business_type,
      v_uid,
      coalesce(nullif(trim(p_currency_code), ''), 'PHP'),
      coalesce(nullif(trim(p_currency_symbol), ''), '₱'),
      v_mode,
      'free',
      1
    )
    returning id into v_store_id;

    insert into public.branches (store_id, name, is_primary)
    values (v_store_id, coalesce(nullif(trim(p_primary_branch_name), ''), 'Main'), true);

    insert into public.store_members (store_id, user_id, role, status)
    values (v_store_id, v_uid, 'owner', 'active');

    insert into public.subscriptions (
      store_id,
      plan_tier,
      status,
      provider,
      current_period_start,
      current_period_end
    ) values (
      v_store_id,
      'free',
      'past_due',
      'pending_web',
      now(),
      now()
    );
  else
    insert into public.stores (
      name,
      business_type,
      owner_id,
      currency_code,
      currency_symbol,
      service_pricing_mode,
      plan_tier,
      monthly_transaction_limit
    ) values (
      trim(p_name),
      p_business_type,
      v_uid,
      coalesce(nullif(trim(p_currency_code), ''), 'PHP'),
      coalesce(nullif(trim(p_currency_symbol), ''), '₱'),
      v_mode,
      'premium',
      100000
    )
    returning id into v_store_id;

    insert into public.branches (store_id, name, is_primary)
    values (v_store_id, coalesce(nullif(trim(p_primary_branch_name), ''), 'Main'), true);

    insert into public.store_members (store_id, user_id, role, status)
    values (v_store_id, v_uid, 'owner', 'active');

    insert into public.subscriptions (
      store_id,
      plan_tier,
      status,
      provider,
      current_period_start,
      current_period_end
    ) values (
      v_store_id,
      'premium',
      'active',
      'manual',
      now(),
      '2099-12-31T23:59:59Z'::timestamptz
    );
  end if;

  return v_store_id;
end;
$$;

grant execute on function public.create_store(
  text, public.business_type, text, text, text, public.service_pricing_mode, boolean
) to authenticated;

-- When PayMongo unlocks Premium, clear any leftover free/pending state cleanly
-- (apply_store already sets plan_tier + subscription; keep that path).
