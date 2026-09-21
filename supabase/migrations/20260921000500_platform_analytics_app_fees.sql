-- Platform analytics: "sales" = ₱199 app fee payments (not store POS orders).

create or replace function public.platform_analytics_series(p_days int default 30)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_days int := least(greatest(coalesce(p_days, 30), 7), 90);
  v_start date := ((timezone('Asia/Manila', now()))::date - (v_days - 1));
  v_series jsonb := '[]'::jsonb;
  v_registered int := 0;
  v_converted int := 0;
  v_sales int := 0;
  v_gmv numeric := 0;
  v_fee_today int := 0;
  v_fee_7d int := 0;
  v_rev_today numeric := 0;
  v_rev_7d numeric := 0;
  v_today date := (timezone('Asia/Manila', now()))::date;
  v_week_start date := v_today - 6;
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  with days as (
    select generate_series(v_start, v_today, '1 day'::interval)::date as day
  ),
  regs as (
    select (timezone('Asia/Manila', s.created_at))::date as day, count(*)::int as n
    from public.stores s
    where (timezone('Asia/Manila', s.created_at))::date >= v_start
    group by 1
  ),
  -- One unlock per store: PayMongo checkout and/or App Store / Play / RC Premium.
  first_app_pay as (
    select
      u.store_id,
      min(u.unlocked_at) as unlocked_at,
      max(u.amount_centavos)::int as amount_centavos
    from (
      select
        b.store_id,
        b.paid_at as unlocked_at,
        b.amount_centavos
      from public.billing_checkout_sessions b
      where b.status = 'paid'
        and b.paid_at is not null
      union all
      select
        sub.store_id,
        coalesce(sub.current_period_start, sub.updated_at) as unlocked_at,
        19900 as amount_centavos
      from public.subscriptions sub
      where sub.status = 'active'
        and sub.plan_tier = 'premium'
        and sub.provider in ('paymongo', 'revenuecat', 'app_store', 'play_store')
    ) u
    group by u.store_id
  ),
  fees as (
    select
      (timezone('Asia/Manila', f.unlocked_at))::date as day,
      count(*)::int as n,
      coalesce(sum(f.amount_centavos), 0) / 100.0 as gmv
    from first_app_pay f
    where (timezone('Asia/Manila', f.unlocked_at))::date >= v_start
    group by 1
  ),
  joined as (
    select
      d.day,
      coalesce(r.n, 0) as registered,
      coalesce(f.n, 0) as converted,
      coalesce(f.n, 0) as sales,
      coalesce(f.gmv, 0) as gmv
    from days d
    left join regs r on r.day = d.day
    left join fees f on f.day = d.day
    order by d.day
  )
  select
    coalesce(jsonb_agg(
      jsonb_build_object(
        'day', day,
        'registered', registered,
        'converted', converted,
        'sales', sales,
        'gmv', gmv
      )
      order by day
    ), '[]'::jsonb),
    coalesce(sum(registered), 0)::int,
    coalesce(sum(converted), 0)::int,
    coalesce(sum(sales), 0)::int,
    coalesce(sum(gmv), 0)
  into v_series, v_registered, v_converted, v_sales, v_gmv
  from joined;

  select
    count(*) filter (
      where (timezone('Asia/Manila', unlocked_at))::date = v_today
    )::int,
    count(*) filter (
      where (timezone('Asia/Manila', unlocked_at))::date >= v_week_start
    )::int,
    coalesce(sum(amount_centavos) filter (
      where (timezone('Asia/Manila', unlocked_at))::date = v_today
    ), 0) / 100.0,
    coalesce(sum(amount_centavos) filter (
      where (timezone('Asia/Manila', unlocked_at))::date >= v_week_start
    ), 0) / 100.0
  into v_fee_today, v_fee_7d, v_rev_today, v_rev_7d
  from (
    select
      u.store_id,
      min(u.unlocked_at) as unlocked_at,
      max(u.amount_centavos)::int as amount_centavos
    from (
      select b.store_id, b.paid_at as unlocked_at, b.amount_centavos
      from public.billing_checkout_sessions b
      where b.status = 'paid' and b.paid_at is not null
      union all
      select
        sub.store_id,
        coalesce(sub.current_period_start, sub.updated_at),
        19900
      from public.subscriptions sub
      where sub.status = 'active'
        and sub.plan_tier = 'premium'
        and sub.provider in ('paymongo', 'revenuecat', 'app_store', 'play_store')
    ) u
    group by u.store_id
  ) x;

  return jsonb_build_object(
    'days', v_days,
    'start_day', v_start,
    'metric', 'app_fee',
    'fee_pesos', 199,
    'totals', jsonb_build_object(
      'registered', v_registered,
      'converted', v_converted,
      'sales', v_sales,
      'gmv', v_gmv,
      'app_fees_today', v_fee_today,
      'app_fees_7d', v_fee_7d,
      'app_revenue_today', v_rev_today,
      'app_revenue_7d', v_rev_7d,
      'conversion_rate', case
        when v_registered <= 0 then 0
        else round((
          (
            select count(*)::numeric
            from public.stores s
            where (timezone('Asia/Manila', s.created_at))::date >= v_start
              and (
                exists (
                  select 1
                  from public.billing_checkout_sessions b
                  where b.store_id = s.id and b.status = 'paid'
                )
                or exists (
                  select 1
                  from public.subscriptions sub
                  where sub.store_id = s.id
                    and sub.status = 'active'
                    and sub.plan_tier = 'premium'
                    and sub.provider in ('paymongo', 'revenuecat', 'app_store', 'play_store')
                )
              )
          ) / nullif(v_registered::numeric, 0)
        ) * 100, 1)
      end
    ),
    'series', v_series
  );
end;
$$;

grant execute on function public.platform_analytics_series(int) to authenticated;

-- Top strip: keep store POS activity, add ₱199 app-fee counters.
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

  with first_app_pay as (
    select
      u.store_id,
      min(u.unlocked_at) as unlocked_at,
      max(u.amount_centavos)::int as amount_centavos
    from (
      select b.store_id, b.paid_at as unlocked_at, b.amount_centavos
      from public.billing_checkout_sessions b
      where b.status = 'paid' and b.paid_at is not null
      union all
      select
        sub.store_id,
        coalesce(sub.current_period_start, sub.updated_at),
        19900
      from public.subscriptions sub
      where sub.status = 'active'
        and sub.plan_tier = 'premium'
        and sub.provider in ('paymongo', 'revenuecat', 'app_store', 'play_store')
    ) u
    group by u.store_id
  )
  select
    count(*) filter (where unlocked_at >= v_today_start)::int,
    count(*) filter (where unlocked_at >= v_week_start)::int,
    coalesce(sum(amount_centavos) filter (where unlocked_at >= v_today_start), 0) / 100.0,
    coalesce(sum(amount_centavos) filter (where unlocked_at >= v_week_start), 0) / 100.0
  into v_fee_today, v_fee_7d, v_rev_today, v_rev_7d
  from first_app_pay;

  return jsonb_build_object(
    'total_stores', (select count(*)::int from public.stores),
    'active_stores_today', (
      select count(distinct store_id)::int
      from public.transactions
      where status = 'paid'
        and coalesce(paid_at, created_at) >= v_today_start
    ),
    'active_stores_7d', (
      select count(distinct store_id)::int
      from public.transactions
      where status = 'paid'
        and coalesce(paid_at, created_at) >= v_week_start
    ),
    'paid_today', (
      select count(*)::int
      from public.transactions
      where status = 'paid'
        and coalesce(paid_at, created_at) >= v_today_start
    ),
    'paid_7d', (
      select count(*)::int
      from public.transactions
      where status = 'paid'
        and coalesce(paid_at, created_at) >= v_week_start
    ),
    'gmv_today', (
      select coalesce(sum(total - coalesce(refunded_total, 0)), 0)
      from public.transactions
      where status = 'paid'
        and coalesce(paid_at, created_at) >= v_today_start
    ),
    'gmv_7d', (
      select coalesce(sum(total - coalesce(refunded_total, 0)), 0)
      from public.transactions
      where status = 'paid'
        and coalesce(paid_at, created_at) >= v_week_start
    ),
    'app_fees_today', v_fee_today,
    'app_fees_7d', v_fee_7d,
    'app_revenue_today', v_rev_today,
    'app_revenue_7d', v_rev_7d
  );
end;
$$;

grant execute on function public.platform_usage_overview() to authenticated;
