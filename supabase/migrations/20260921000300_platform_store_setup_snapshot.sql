-- Platform Ops: read-only store setup snapshot (catalog / branches). Admin only.

create or replace function public.platform_get_store_setup(p_store_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_products int := 0;
  v_active int := 0;
  v_categories int := 0;
  v_branches int := 0;
  v_latest timestamptz;
  v_items jsonb := '[]'::jsonb;
  v_cats jsonb := '[]'::jsonb;
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  if p_store_id is null or not exists (select 1 from public.stores where id = p_store_id) then
    raise exception 'STORE_NOT_FOUND' using errcode = 'P0001';
  end if;

  select count(*)::int,
         count(*) filter (where is_active)::int,
         max(created_at)
    into v_products, v_active, v_latest
  from public.products
  where store_id = p_store_id;

  select count(*)::int into v_categories
  from public.categories
  where store_id = p_store_id;

  select count(*)::int into v_branches
  from public.branches
  where store_id = p_store_id;

  select coalesce(jsonb_agg(to_jsonb(r) order by r.sort_name), '[]'::jsonb)
  into v_items
  from (
    select
      p.id,
      p.name,
      p.price,
      p.stock,
      p.is_active,
      p.kind::text as kind,
      p.sku,
      c.name as category_name,
      p.created_at,
      lower(p.name) as sort_name
    from public.products p
    left join public.categories c on c.id = p.category_id
    where p.store_id = p_store_id
    order by p.is_active desc, p.created_at desc
    limit 20
  ) r;

  select coalesce(jsonb_agg(to_jsonb(c) order by c.name), '[]'::jsonb)
  into v_cats
  from (
    select cat.id, cat.name, cat.sort_order
    from public.categories cat
    where cat.store_id = p_store_id
    order by cat.sort_order, cat.name
    limit 30
  ) c;

  return jsonb_build_object(
    'store_id', p_store_id,
    'product_count', v_products,
    'active_product_count', v_active,
    'category_count', v_categories,
    'branch_count', v_branches,
    'has_catalog', v_products > 0,
    'latest_product_at', v_latest,
    'products', v_items,
    'categories', v_cats
  );
end;
$$;

grant execute on function public.platform_get_store_setup(uuid) to authenticated;

-- Sidebar hint: product counts on tenant list.
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
            select count(*)::int
            from public.store_members m
            where m.store_id = s.id and m.status = 'active'
          ) as active_members,
          (
            select count(*)::int
            from public.products pr
            where pr.store_id = s.id
          ) as product_count,
          (
            select count(*)::int
            from public.products pr
            where pr.store_id = s.id and pr.is_active
          ) as active_product_count,
          sub.status::text as subscription_status
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
