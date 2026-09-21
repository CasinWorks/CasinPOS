-- Platform Ops: usage overview + recent transactions (admin only, max 10 per page).

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
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

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
    )
  );
end;
$$;

grant execute on function public.platform_usage_overview() to authenticated;

create or replace function public.platform_list_recent_transactions(
  p_store_id uuid default null,
  p_limit int default 10,
  p_offset int default 0
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit int := least(greatest(coalesce(p_limit, 10), 1), 10);
  v_offset int := greatest(coalesce(p_offset, 0), 0);
  v_total int := 0;
  v_rows jsonb := '[]'::jsonb;
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  select count(*)::int into v_total
  from public.transactions t
  where (p_store_id is null or t.store_id = p_store_id)
    and t.status in ('paid', 'voided', 'refunded');

  select coalesce(jsonb_agg(to_jsonb(r) order by r.sort_at desc), '[]'::jsonb)
  into v_rows
  from (
    select
      t.id,
      t.store_id,
      s.name as store_name,
      t.order_no,
      t.status::text as status,
      t.business_type::text as business_type,
      t.subtotal,
      t.tax,
      t.total,
      coalesce(t.refunded_total, 0) as refunded_total,
      t.currency_code,
      t.payment_method::text as payment_method,
      t.customer_name,
      t.paid_at,
      t.created_at,
      coalesce(t.paid_at, t.created_at) as sort_at,
      p.full_name as staff_name,
      u.email as staff_email,
      (
        select count(*)::int
        from public.transaction_items ti
        where ti.transaction_id = t.id
      ) as item_count,
      coalesce(
        (
          select jsonb_agg(
            jsonb_build_object(
              'name', ti.name_snapshot,
              'quantity', ti.quantity,
              'unit_price', ti.unit_price,
              'line_total', ti.line_total
            )
            order by ti.id
          )
          from public.transaction_items ti
          where ti.transaction_id = t.id
        ),
        '[]'::jsonb
      ) as items
    from public.transactions t
    join public.stores s on s.id = t.store_id
    left join public.profiles p on p.id = t.staff_id
    left join auth.users u on u.id = t.staff_id
    where (p_store_id is null or t.store_id = p_store_id)
      and t.status in ('paid', 'voided', 'refunded')
    order by coalesce(t.paid_at, t.created_at) desc
    limit v_limit
    offset v_offset
  ) r;

  return jsonb_build_object(
    'transactions', v_rows,
    'total_count', v_total,
    'limit', v_limit,
    'offset', v_offset,
    'has_more', (v_offset + v_limit) < v_total
  );
end;
$$;

grant execute on function public.platform_list_recent_transactions(uuid, int, int) to authenticated;
