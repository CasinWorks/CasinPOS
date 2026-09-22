-- Track signup channel. iOS (and Mac App Store) are paid apps → converted on create.
-- Web converts only after PayMongo ₱199.

alter table public.stores
  add column if not exists signup_channel text;

alter table public.stores
  drop constraint if exists stores_signup_channel_chk;

alter table public.stores
  add constraint stores_signup_channel_chk
  check (signup_channel is null or signup_channel in ('web', 'ios', 'macos', 'android', 'unknown'));

comment on column public.stores.signup_channel is
  'Where the owner created the store: web, ios, macos, android, unknown.';

-- Existing web checkouts / pending web signups.
update public.stores s
set signup_channel = 'web'
from public.subscriptions sub
where sub.store_id = s.id
  and s.signup_channel is null
  and sub.provider in ('pending_web', 'paymongo');

update public.stores s
set signup_channel = 'web'
where s.signup_channel is null
  and exists (
    select 1
    from public.billing_checkout_sessions b
    where b.store_id = s.id
  );

-- ---------------------------------------------------------------------------
-- create_store records channel. iOS/macOS stay Premium (already paid).
-- ---------------------------------------------------------------------------
drop function if exists public.create_store(
  text, public.business_type, text, text, text, public.service_pricing_mode, boolean
);

create function public.create_store(
  p_name text,
  p_business_type public.business_type,
  p_currency_code text default 'PHP',
  p_currency_symbol text default '₱',
  p_primary_branch_name text default 'Main',
  p_service_pricing_mode public.service_pricing_mode default null,
  p_pending_web_payment boolean default false,
  p_signup_channel text default null
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
  v_channel text := lower(trim(coalesce(p_signup_channel, '')));
  v_provider text;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if length(trim(p_name)) < 1 then
    raise exception 'STORE_NAME_REQUIRED';
  end if;

  if v_pending then
    v_channel := 'web';
  elsif v_channel not in ('web', 'ios', 'macos', 'android') then
    v_channel := 'unknown';
  end if;

  v_mode := case
    when p_business_type = 'service' then coalesce(p_service_pricing_mode, 'fixed')
    else null
  end;

  v_provider := case
    when v_channel = 'web' and v_pending then 'pending_web'
    when v_channel in ('ios', 'macos') then 'app_store'
    when v_channel = 'android' then 'play_store'
    else 'manual'
  end;

  if v_pending then
    insert into public.stores (
      name, business_type, owner_id, currency_code, currency_symbol,
      service_pricing_mode, plan_tier, monthly_transaction_limit, signup_channel
    ) values (
      trim(p_name), p_business_type, v_uid,
      coalesce(nullif(trim(p_currency_code), ''), 'PHP'),
      coalesce(nullif(trim(p_currency_symbol), ''), '₱'),
      v_mode, 'free', 1, v_channel
    )
    returning id into v_store_id;

    insert into public.branches (store_id, name, is_primary)
    values (v_store_id, coalesce(nullif(trim(p_primary_branch_name), ''), 'Main'), true);

    insert into public.store_members (store_id, user_id, role, status)
    values (v_store_id, v_uid, 'owner', 'active');

    insert into public.subscriptions (
      store_id, plan_tier, status, provider, current_period_start, current_period_end
    ) values (
      v_store_id, 'free', 'past_due', v_provider, now(), now()
    );
  else
    insert into public.stores (
      name, business_type, owner_id, currency_code, currency_symbol,
      service_pricing_mode, plan_tier, monthly_transaction_limit, signup_channel
    ) values (
      trim(p_name), p_business_type, v_uid,
      coalesce(nullif(trim(p_currency_code), ''), 'PHP'),
      coalesce(nullif(trim(p_currency_symbol), ''), '₱'),
      v_mode, 'premium', 100000, v_channel
    )
    returning id into v_store_id;

    insert into public.branches (store_id, name, is_primary)
    values (v_store_id, coalesce(nullif(trim(p_primary_branch_name), ''), 'Main'), true);

    insert into public.store_members (store_id, user_id, role, status)
    values (v_store_id, v_uid, 'owner', 'active');

    insert into public.subscriptions (
      store_id, plan_tier, status, provider, current_period_start, current_period_end
    ) values (
      v_store_id, 'premium', 'active', v_provider, now(), '2099-12-31T23:59:59Z'::timestamptz
    );
  end if;

  return v_store_id;
end;
$$;

grant execute on function public.create_store(
  text, public.business_type, text, text, text, public.service_pricing_mode, boolean, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- Analytics: iOS/Mac count as converted on the day the store is created.
-- Web counts as converted only when PayMongo is paid.
-- ---------------------------------------------------------------------------
create or replace function public.platform_analytics_series(p_days int default 30)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_days int := least(greatest(coalesce(p_days, 30), 7), 90);
  v_today date := (timezone('Asia/Manila', now()))::date;
  v_start date := v_today - (v_days - 1);
  v_series jsonb := '[]'::jsonb;
  v_registered int := 0;
  v_registered_ios int := 0;
  v_registered_web int := 0;
  v_converted int := 0;
  v_web_paid int := 0;
  v_gmv numeric := 0;
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  with days as (
    select generate_series(v_start, v_today, '1 day'::interval)::date as day
  ),
  regs as (
    select
      (timezone('Asia/Manila', s.created_at))::date as day,
      count(*)::int as n,
      count(*) filter (where s.signup_channel = 'ios')::int as n_ios,
      count(*) filter (where s.signup_channel = 'macos')::int as n_macos,
      count(*) filter (where s.signup_channel = 'web')::int as n_web
    from public.stores s
    where (timezone('Asia/Manila', s.created_at))::date >= v_start
    group by 1
  ),
  web_paid as (
    select
      (timezone('Asia/Manila', b.paid_at))::date as day,
      count(distinct b.store_id)::int as n,
      coalesce(sum(b.amount_centavos), 0) / 100.0 as gmv
    from public.billing_checkout_sessions b
    where b.status = 'paid'
      and b.paid_at is not null
      and (timezone('Asia/Manila', b.paid_at))::date >= v_start
    group by 1
  ),
  joined as (
    select
      d.day,
      coalesce(r.n, 0) as registered,
      coalesce(r.n_ios, 0) as registered_ios,
      coalesce(r.n_macos, 0) as registered_macos,
      coalesce(r.n_web, 0) as registered_web,
      coalesce(w.n, 0) as web_paid,
      coalesce(r.n_ios, 0) + coalesce(r.n_macos, 0) + coalesce(w.n, 0) as converted,
      (coalesce(r.n_ios, 0) + coalesce(r.n_macos, 0)) * 199
        + coalesce(w.gmv, 0) as gmv
    from days d
    left join regs r on r.day = d.day
    left join web_paid w on w.day = d.day
    order by d.day
  )
  select
    coalesce(jsonb_agg(jsonb_build_object(
      'day', day,
      'registered', registered,
      'registered_ios', registered_ios,
      'registered_macos', registered_macos,
      'registered_web', registered_web,
      'web_paid', web_paid,
      'converted', converted,
      'sales', converted,
      'gmv', gmv
    ) order by day), '[]'::jsonb),
    coalesce(sum(registered), 0)::int,
    coalesce(sum(registered_ios), 0)::int,
    coalesce(sum(registered_web), 0)::int,
    coalesce(sum(converted), 0)::int,
    coalesce(sum(web_paid), 0)::int,
    coalesce(sum(gmv), 0)
  into v_series, v_registered, v_registered_ios, v_registered_web, v_converted, v_web_paid, v_gmv
  from joined;

  return jsonb_build_object(
    'days', v_days,
    'start_day', v_start,
    'metric', 'app_fee_by_channel',
    'fee_pesos', 199,
    'totals', jsonb_build_object(
      'registered', v_registered,
      'registered_ios', v_registered_ios,
      'registered_web', v_registered_web,
      'web_paid', v_web_paid,
      'converted', v_converted,
      'sales', v_converted,
      'gmv', v_gmv,
      'conversion_rate', case
        when (v_registered_ios + v_registered_web) <= 0 then 0
        else round((v_converted::numeric / (v_registered_ios + v_registered_web)::numeric) * 100, 1)
      end
    ),
    'series', v_series
  );
end;
$$;

grant execute on function public.platform_analytics_series(int) to authenticated;

-- Top chips: ₱199 today/7d includes iOS/Mac store creates + PayMongo payments.
create or replace function public.platform_usage_overview()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_today date := (timezone('Asia/Manila', now()))::date;
  v_today_start timestamptz := (v_today::timestamp at time zone 'Asia/Manila');
  v_week_start timestamptz := v_today_start - interval '7 days';
  v_fee_today int := 0;
  v_fee_7d int := 0;
  v_rev_today numeric := 0;
  v_rev_7d numeric := 0;
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  with unlocks as (
    select s.created_at as unlocked_at, 19900 as amount_centavos
    from public.stores s
    where s.signup_channel in ('ios', 'macos')
    union all
    select b.paid_at, b.amount_centavos
    from public.billing_checkout_sessions b
    where b.status = 'paid' and b.paid_at is not null
  )
  select
    count(*) filter (where unlocked_at >= v_today_start)::int,
    count(*) filter (where unlocked_at >= v_week_start)::int,
    coalesce(sum(amount_centavos) filter (where unlocked_at >= v_today_start), 0) / 100.0,
    coalesce(sum(amount_centavos) filter (where unlocked_at >= v_week_start), 0) / 100.0
  into v_fee_today, v_fee_7d, v_rev_today, v_rev_7d
  from unlocks;

  return jsonb_build_object(
    'total_stores', (select count(*)::int from public.stores),
    'active_stores_today', (
      select count(distinct store_id)::int from public.transactions
      where status = 'paid' and coalesce(paid_at, created_at) >= v_today_start
    ),
    'active_stores_7d', (
      select count(distinct store_id)::int from public.transactions
      where status = 'paid' and coalesce(paid_at, created_at) >= v_week_start
    ),
    'paid_today', (
      select count(*)::int from public.transactions
      where status = 'paid' and coalesce(paid_at, created_at) >= v_today_start
    ),
    'paid_7d', (
      select count(*)::int from public.transactions
      where status = 'paid' and coalesce(paid_at, created_at) >= v_week_start
    ),
    'gmv_today', (
      select coalesce(sum(total - coalesce(refunded_total, 0)), 0) from public.transactions
      where status = 'paid' and coalesce(paid_at, created_at) >= v_today_start
    ),
    'gmv_7d', (
      select coalesce(sum(total - coalesce(refunded_total, 0)), 0) from public.transactions
      where status = 'paid' and coalesce(paid_at, created_at) >= v_week_start
    ),
    'app_fees_today', v_fee_today,
    'app_fees_7d', v_fee_7d,
    'app_revenue_today', v_rev_today,
    'app_revenue_7d', v_rev_7d
  );
end;
$$;

grant execute on function public.platform_usage_overview() to authenticated;

create or replace function public.platform_list_tenants(p_search text default null)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_q text := nullif(trim(coalesce(p_search, '')), '');
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  return coalesce(
    (
      select jsonb_agg(to_jsonb(t))
      from (
        select
          s.id,
          s.name,
          s.business_type::text as business_type,
          s.plan_tier::text as plan_tier,
          s.signup_channel,
          s.transactions_this_period,
          s.monthly_transaction_limit,
          s.billing_period_start,
          s.suspended_at,
          s.suspension_reason,
          s.created_at,
          s.updated_at,
          s.owner_id,
          u.email as owner_email,
          p.full_name as owner_name,
          (
            select count(*)::int from public.store_members m
            where m.store_id = s.id and m.status = 'active'
          ) as active_members,
          (
            select count(*)::int from public.products pr where pr.store_id = s.id
          ) as product_count,
          (
            select count(*)::int from public.products pr
            where pr.store_id = s.id and pr.is_active
          ) as active_product_count,
          sub.status::text as subscription_status,
          sub.provider as billing_provider
        from public.stores s
        left join public.profiles p on p.id = s.owner_id
        left join auth.users u on u.id = s.owner_id
        left join public.subscriptions sub on sub.store_id = s.id
        where v_q is null
           or s.name ilike '%' || v_q || '%'
           or coalesce(u.email, '') ilike '%' || v_q || '%'
           or coalesce(p.full_name, '') ilike '%' || v_q || '%'
           or s.id::text ilike '%' || v_q || '%'
        order by s.created_at desc
        limit 200
      ) t
    ),
    '[]'::jsonb
  );
end;
$$;

grant execute on function public.platform_list_tenants(text) to authenticated;
