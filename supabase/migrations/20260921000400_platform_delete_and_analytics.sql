-- Platform Ops: analytics series + helpers for admin tenant delete (Edge Function).

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
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  with days as (
    select generate_series(v_start, (timezone('Asia/Manila', now()))::date, '1 day'::interval)::date as day
  ),
  regs as (
    select (timezone('Asia/Manila', s.created_at))::date as day, count(*)::int as n
    from public.stores s
    where (timezone('Asia/Manila', s.created_at))::date >= v_start
    group by 1
  ),
  first_paid as (
    select
      t.store_id,
      min(timezone('Asia/Manila', coalesce(t.paid_at, t.created_at)))::date as first_day
    from public.transactions t
    where t.status = 'paid'
    group by t.store_id
  ),
  conv as (
    select first_day as day, count(*)::int as n
    from first_paid
    where first_day >= v_start
    group by 1
  ),
  sales as (
    select
      (timezone('Asia/Manila', coalesce(t.paid_at, t.created_at)))::date as day,
      count(*)::int as n,
      coalesce(sum(t.total - coalesce(t.refunded_total, 0)), 0) as gmv
    from public.transactions t
    where t.status = 'paid'
      and (timezone('Asia/Manila', coalesce(t.paid_at, t.created_at)))::date >= v_start
    group by 1
  ),
  joined as (
    select
      d.day,
      coalesce(r.n, 0) as registered,
      coalesce(c.n, 0) as converted,
      coalesce(s.n, 0) as sales,
      coalesce(s.gmv, 0) as gmv
    from days d
    left join regs r on r.day = d.day
    left join conv c on c.day = d.day
    left join sales s on s.day = d.day
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

  return jsonb_build_object(
    'days', v_days,
    'start_day', v_start,
    'totals', jsonb_build_object(
      'registered', v_registered,
      'converted', v_converted,
      'sales', v_sales,
      'gmv', v_gmv,
      'conversion_rate', case
        when v_registered <= 0 then 0
        else round((
          (
            select count(*)::numeric
            from public.stores s
            where (timezone('Asia/Manila', s.created_at))::date >= v_start
              and exists (
                select 1
                from public.transactions t
                where t.store_id = s.id
                  and t.status = 'paid'
              )
          ) / nullif((
            select count(*)::numeric
            from public.stores s2
            where (timezone('Asia/Manila', s2.created_at))::date >= v_start
          ), 0)
        ) * 100, 1)
      end
    ),
    'series', v_series
  );
end;
$$;

grant execute on function public.platform_analytics_series(int) to authenticated;

-- True when caller is platform admin (Edge Function double-check via user JWT + RPC).
create or replace function public.platform_assert_admin()
returns boolean
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
  return true;
end;
$$;

grant execute on function public.platform_assert_admin() to authenticated;

-- Look up tenant delete target (admin only). Service role uses this via user JWT client.
create or replace function public.platform_tenant_delete_preview(p_store_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store public.stores%rowtype;
  v_email text;
  v_name text;
  v_other_stores int := 0;
  v_is_admin boolean := false;
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  select * into v_store from public.stores where id = p_store_id;
  if not found then
    raise exception 'STORE_NOT_FOUND' using errcode = 'P0001';
  end if;

  select u.email, p.full_name, coalesce(p.is_platform_admin, false)
    into v_email, v_name, v_is_admin
  from auth.users u
  left join public.profiles p on p.id = u.id
  where u.id = v_store.owner_id;

  select count(*)::int into v_other_stores
  from public.stores s
  where s.owner_id = v_store.owner_id
    and s.id <> p_store_id;

  return jsonb_build_object(
    'store_id', v_store.id,
    'store_name', v_store.name,
    'owner_id', v_store.owner_id,
    'owner_email', v_email,
    'owner_name', v_name,
    'owner_is_platform_admin', v_is_admin,
    'other_owned_stores', v_other_stores,
    'will_delete_auth_user', v_other_stores = 0 and coalesce(v_is_admin, false) = false
  );
end;
$$;

grant execute on function public.platform_tenant_delete_preview(uuid) to authenticated;
