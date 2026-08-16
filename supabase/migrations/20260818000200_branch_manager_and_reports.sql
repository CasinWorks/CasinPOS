  -- Branch Manager role + report RPCs + inventory COGS helper columns.
  -- Safe to re-run pieces; enum add is idempotent on PG 15+.

  -- Role enum added in 20260818000100_branch_manager_role_enum.sql

  -- Invitation role check (franchise allowed owner; include branch_manager)
  alter table public.store_invitations
    drop constraint if exists store_invitations_role_check;

  alter table public.store_invitations
    add constraint store_invitations_role_check
    check (role in ('owner', 'admin', 'manager', 'branch_manager', 'staff'));

  -- ---------------------------------------------------------------------------
  -- 2) Product fields for inventory / profitability reports
  --    unit_cost = existing cost_price (no rename). Add supplier + restock date.
  -- ---------------------------------------------------------------------------
  alter table public.products
    add column if not exists supplier_name text,
    add column if not exists last_restocked_at timestamptz;

  comment on column public.products.cost_price is 'Unit cost (COGS) used in profitability reports';
  comment on column public.products.supplier_name is 'Optional supplier label for inventory reports';
  comment on column public.products.last_restocked_at is 'Last restock timestamp for inventory reports';

  -- ---------------------------------------------------------------------------
  -- 3) Branch-scope helpers
  -- ---------------------------------------------------------------------------
  create or replace function public.member_accessible_branch_ids(p_store_id uuid)
  returns uuid[]
  language plpgsql
  stable
  security definer
  set search_path = public
  as $$
  declare
    v_role public.store_role;
    v_ids uuid[];
  begin
    if auth.uid() is null then
      return array[]::uuid[];
    end if;

    select m.role, m.branch_ids
    into v_role, v_ids
    from public.store_members m
    where m.store_id = p_store_id
      and m.user_id = auth.uid()
      and m.status = 'active'
    limit 1;

    if v_role is null then
      return array[]::uuid[];
    end if;

    -- Owner / admin / manager / staff with null branch_ids → all branches
    if v_role <> 'branch_manager' and (v_ids is null or cardinality(v_ids) = 0) then
      return array(
        select b.id from public.branches b where b.store_id = p_store_id order by b.is_primary desc, b.name
      );
    end if;

    -- Branch manager (or scoped member): only assigned branches that still exist
    return array(
      select b.id
      from public.branches b
      where b.store_id = p_store_id
        and b.id = any (coalesce(v_ids, array[]::uuid[]))
      order by b.is_primary desc, b.name
    );
  end;
  $$;

  create or replace function public.can_access_store_branch(p_store_id uuid, p_branch_id uuid)
  returns boolean
  language sql
  stable
  security definer
  set search_path = public
  as $$
    select p_branch_id is not null
      and p_branch_id = any (public.member_accessible_branch_ids(p_store_id));
  $$;

  create or replace function public.can_view_store_reports(p_store_id uuid)
  returns boolean
  language sql
  stable
  security definer
  set search_path = public
  as $$
    select exists (
      select 1
      from public.store_members m
      where m.store_id = p_store_id
        and m.user_id = auth.uid()
        and m.status = 'active'
        and m.role in ('owner', 'admin', 'manager', 'branch_manager')
    );
  $$;

  grant execute on function public.member_accessible_branch_ids(uuid) to authenticated;
  grant execute on function public.can_access_store_branch(uuid, uuid) to authenticated;
  grant execute on function public.can_view_store_reports(uuid) to authenticated;

  -- ---------------------------------------------------------------------------
  -- 4) RLS: transactions visible by branch scope for branch_manager
  -- ---------------------------------------------------------------------------
  drop policy if exists transactions_select_member on public.transactions;
  create policy transactions_select_member on public.transactions
    for select using (
      public.is_store_member(store_id)
      and (
        public.member_role(store_id) is distinct from 'branch_manager'::public.store_role
        or public.can_access_store_branch(store_id, branch_id)
      )
    );

  -- Products: branch_manager may read all store products (stock is store-level);
  -- write stays as existing member policies. No change required for select.

  -- ---------------------------------------------------------------------------
  -- 5) List branches (scoped)
  -- ---------------------------------------------------------------------------
  create or replace function public.list_store_branches(p_store_id uuid)
  returns table (
    id uuid,
    name text,
    address text,
    is_primary boolean
  )
  language plpgsql
  stable
  security definer
  set search_path = public
  as $$
  begin
    if not public.is_store_member(p_store_id) then
      raise exception 'FORBIDDEN' using errcode = 'P0001';
    end if;

    return query
    select b.id, b.name, b.address, b.is_primary
    from public.branches b
    where b.store_id = p_store_id
      and b.id = any (public.member_accessible_branch_ids(p_store_id))
    order by b.is_primary desc, b.name;
  end;
  $$;

  grant execute on function public.list_store_branches(uuid) to authenticated;

  -- ---------------------------------------------------------------------------
  -- 6) Invite: allow branch_manager; require branch_ids for that role
  -- ---------------------------------------------------------------------------
  create or replace function public.create_store_invitation(
    p_store_id uuid,
    p_email text,
    p_role public.store_role,
    p_branch_ids uuid[] default null
  )
  returns jsonb
  language plpgsql
  security definer
  set search_path = public
  as $$
  declare
    v_email text := lower(trim(p_email));
    v_row public.store_invitations;
    v_actor public.store_role;
    v_limit int;
    v_used int;
    v_valid_branches uuid[];
  begin
    if auth.uid() is null then
      raise exception 'NOT_AUTHENTICATED' using errcode = 'P0001';
    end if;

    if not public.has_store_role(p_store_id, array['owner', 'admin']::public.store_role[]) then
      raise exception 'FORBIDDEN' using errcode = 'P0001';
    end if;

    select public.member_role(p_store_id) into v_actor;

    if p_role = 'owner' then
      raise exception 'CANNOT_INVITE_OWNER' using errcode = 'P0001';
    end if;

    if p_role = 'admin' and v_actor is distinct from 'owner' then
      raise exception 'ADMIN_CANNOT_INVITE_ADMIN' using errcode = 'P0001';
    end if;

    if p_role not in ('admin', 'manager', 'branch_manager', 'staff') then
      raise exception 'FORBIDDEN' using errcode = 'P0001';
    end if;

    if v_email is null or v_email !~ '^[^@]+@[^@]+\.[^@]+$' then
      raise exception 'EMAIL_INVALID' using errcode = 'P0001';
    end if;

    -- branch_manager must be assigned at least one valid branch
    if p_role = 'branch_manager' then
      if p_branch_ids is null or cardinality(p_branch_ids) = 0 then
        raise exception 'BRANCH_IDS_REQUIRED' using errcode = 'P0001';
      end if;
      select array_agg(b.id)
      into v_valid_branches
      from public.branches b
      where b.store_id = p_store_id
        and b.id = any (p_branch_ids);
      if v_valid_branches is null or cardinality(v_valid_branches) = 0 then
        raise exception 'BRANCH_IDS_INVALID' using errcode = 'P0001';
      end if;
    else
      v_valid_branches := p_branch_ids;
    end if;

    -- Free seat limit
    select public.free_team_seat_limit() into v_limit;
    if exists (
      select 1 from public.stores s where s.id = p_store_id and s.plan_tier = 'free'
    ) then
      select seats_used into v_used from public.store_seat_usage(p_store_id);
      if coalesce(v_used, 0) >= v_limit then
        raise exception 'FREE_TEAM_SEAT_LIMIT' using errcode = 'P0001';
      end if;
    end if;

    update public.store_invitations
    set
      role = p_role,
      branch_ids = v_valid_branches,
      invited_by = auth.uid(),
      token = encode(gen_random_bytes(24), 'hex'),
      expires_at = now() + interval '14 days',
      status = 'pending',
      updated_at = now()
    where store_id = p_store_id
      and email = v_email
      and status = 'pending'
    returning * into v_row;

    if v_row.id is null then
      insert into public.store_invitations (
        store_id, email, role, branch_ids, invited_by
      ) values (
        p_store_id, v_email, p_role, v_valid_branches, auth.uid()
      )
      returning * into v_row;
    end if;

    return jsonb_build_object(
      'id', v_row.id,
      'store_id', v_row.store_id,
      'email', v_row.email,
      'role', v_row.role,
      'branch_ids', to_jsonb(v_row.branch_ids),
      'token', v_row.token,
      'expires_at', v_row.expires_at,
      'status', v_row.status,
      'resent', true
    );
  end;
  $$;

-- ---------------------------------------------------------------------------
-- 7) Update member role + branch assignment
-- Existing function returns void — must DROP before changing to jsonb.
-- ---------------------------------------------------------------------------
drop function if exists public.update_store_member_role(uuid, public.store_role);
drop function if exists public.update_store_member_role(uuid, public.store_role, uuid[]);

create or replace function public.update_store_member_role(
  p_member_id uuid,
  p_role public.store_role,
  p_branch_ids uuid[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_target public.store_members;
  v_actor public.store_role;
  v_valid_branches uuid[];
begin
  select * into v_target from public.store_members where id = p_member_id;
  if v_target.id is null then
    raise exception 'MEMBER_NOT_FOUND' using errcode = 'P0001';
  end if;
  v_store_id := v_target.store_id;

  if not public.has_store_role(v_store_id, array['owner', 'admin']::public.store_role[]) then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  select public.member_role(v_store_id) into v_actor;

  if v_target.role = 'owner' then
    raise exception 'CANNOT_CHANGE_OWNER_ROLE' using errcode = 'P0001';
  end if;
  if v_target.user_id = auth.uid() then
    raise exception 'CANNOT_CHANGE_OWN_ROLE' using errcode = 'P0001';
  end if;
  if p_role = 'owner' then
    raise exception 'CANNOT_ASSIGN_OWNER' using errcode = 'P0001';
  end if;
  if p_role = 'admin' and v_actor is distinct from 'owner' then
    raise exception 'ADMIN_CANNOT_MANAGE_ADMIN' using errcode = 'P0001';
  end if;
  if v_target.role = 'admin' and v_actor is distinct from 'owner' then
    raise exception 'ADMIN_CANNOT_MANAGE_ADMIN' using errcode = 'P0001';
  end if;

  if p_role = 'branch_manager' then
    if p_branch_ids is null or cardinality(p_branch_ids) = 0 then
      raise exception 'BRANCH_IDS_REQUIRED' using errcode = 'P0001';
    end if;
    select array_agg(b.id)
    into v_valid_branches
    from public.branches b
    where b.store_id = v_store_id
      and b.id = any (p_branch_ids);
    if v_valid_branches is null or cardinality(v_valid_branches) = 0 then
      raise exception 'BRANCH_IDS_INVALID' using errcode = 'P0001';
    end if;
  else
    v_valid_branches := p_branch_ids; -- may be null = all branches
  end if;

  update public.store_members
  set
    role = p_role,
    branch_ids = v_valid_branches,
    updated_at = now()
  where id = p_member_id;

  return jsonb_build_object(
    'ok', true,
    'member_id', p_member_id,
    'role', p_role,
    'branch_ids', to_jsonb(v_valid_branches)
  );
end;
$$;

grant execute on function public.update_store_member_role(uuid, public.store_role, uuid[]) to authenticated;

-- Keep old 2-arg signature working (clients that omit branch_ids)
create or replace function public.update_store_member_role(
  p_member_id uuid,
  p_role public.store_role
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  return public.update_store_member_role(p_member_id, p_role, null);
end;
$$;

grant execute on function public.update_store_member_role(uuid, public.store_role) to authenticated;

  -- ---------------------------------------------------------------------------
  -- 8) Report RPCs
  -- p_branch_id null = all accessible branches (merged for owners)
  -- ---------------------------------------------------------------------------
  create or replace function public.report_inventory(
    p_store_id uuid,
    p_branch_id uuid default null,
    p_low_stock_only boolean default false
  )
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path = public
  as $$
  declare
    v_scope uuid[];
    v_rows jsonb;
  begin
    if not public.can_view_store_reports(p_store_id) then
      raise exception 'FORBIDDEN' using errcode = 'P0001';
    end if;

    v_scope := public.member_accessible_branch_ids(p_store_id);
    if p_branch_id is not null then
      if not (p_branch_id = any (v_scope)) then
        raise exception 'FORBIDDEN' using errcode = 'P0001';
      end if;
      v_scope := array[p_branch_id];
    end if;

    select coalesce(jsonb_agg(to_jsonb(x) order by x.item_name), '[]'::jsonb)
    into v_rows
    from (
      select
        p.sku,
        p.name as item_name,
        coalesce(c.name, 'General') as category,
        coalesce(b.name, pb.name, 'Main') as branch_name,
        coalesce(b.id, pb.id) as branch_id,
        p.stock as current_stock,
        coalesce(p.cost_price, 0)::numeric(12, 2) as unit_cost,
        (p.stock * coalesce(p.cost_price, 0))::numeric(14, 2) as stock_value,
        coalesce(p.low_stock_threshold, 0) as reorder_threshold,
        (p.stock <= coalesce(p.low_stock_threshold, 0)) as low_stock_flag,
        p.last_restocked_at as last_restocked_date,
        p.supplier_name as supplier
      from public.products p
      left join public.categories c on c.id = p.category_id
      left join public.branches b on b.id = p.branch_id
      left join lateral (
        select br.id, br.name
        from public.branches br
        where br.store_id = p.store_id
        order by br.is_primary desc, br.name
        limit 1
      ) pb on true
      where p.store_id = p_store_id
        and p.is_active = true
        and (
          -- Product assigned to a scoped branch, or unassigned (shared) shown under primary
          (p.branch_id is not null and p.branch_id = any (v_scope))
          or (p.branch_id is null and pb.id = any (v_scope))
        )
        and (
          not p_low_stock_only
          or p.stock <= coalesce(p.low_stock_threshold, 0)
        )
    ) x;

    return jsonb_build_object(
      'store_id', p_store_id,
      'branch_ids', to_jsonb(v_scope),
      'rows', v_rows
    );
  end;
  $$;

  create or replace function public.report_sales_lines(
    p_store_id uuid,
    p_start timestamptz,
    p_end timestamptz,
    p_branch_id uuid default null
  )
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path = public
  as $$
  declare
    v_scope uuid[];
    v_rows jsonb;
  begin
    if not public.can_view_store_reports(p_store_id) then
      raise exception 'FORBIDDEN' using errcode = 'P0001';
    end if;

    v_scope := public.member_accessible_branch_ids(p_store_id);
    if p_branch_id is not null then
      if not (p_branch_id = any (v_scope)) then
        raise exception 'FORBIDDEN' using errcode = 'P0001';
      end if;
      v_scope := array[p_branch_id];
    end if;

    select coalesce(jsonb_agg(to_jsonb(x) order by x.date desc, x.time desc), '[]'::jsonb)
    into v_rows
    from (
      select
        t.id as transaction_id,
        t.order_no,
        (t.created_at at time zone 'UTC')::date as date,
        to_char(t.created_at at time zone 'UTC', 'HH24:MI:SS') as time,
        b.name as branch_name,
        t.branch_id,
        ti.name_snapshot as item_name,
        coalesce(c.name, 'General') as category,
        ti.quantity as qty,
        ti.unit_price,
        case
          when t.subtotal > 0 then round((ti.line_total / t.subtotal) * coalesce(t.discount_amount, 0), 2)
          else 0
        end as discount,
        case
          when t.subtotal > 0 then round((ti.line_total / t.subtotal) * coalesce(t.tax, 0), 2)
          else 0
        end as tax,
        ti.line_total,
        t.payment_method::text as payment_method,
        coalesce(nullif(pr.full_name, ''), 'Staff') as staff_name,
        'retail' as order_type
      from public.transactions t
      join public.transaction_items ti on ti.transaction_id = t.id
      join public.branches b on b.id = t.branch_id
      left join public.products p on p.id = ti.product_id
      left join public.categories c on c.id = p.category_id
      left join public.profiles pr on pr.id = t.staff_id
      where t.store_id = p_store_id
        and t.status = 'paid'
        and t.branch_id = any (v_scope)
        and t.created_at >= p_start
        and t.created_at < p_end
    ) x;

    return jsonb_build_object(
      'store_id', p_store_id,
      'branch_ids', to_jsonb(v_scope),
      'start', p_start,
      'end', p_end,
      'rows', v_rows
    );
  end;
  $$;

  create or replace function public.report_profitability(
    p_store_id uuid,
    p_start timestamptz,
    p_end timestamptz,
    p_branch_id uuid default null
  )
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path = public
  as $$
  declare
    v_scope uuid[];
    v_rows jsonb;
  begin
    if not public.can_view_store_reports(p_store_id) then
      raise exception 'FORBIDDEN' using errcode = 'P0001';
    end if;

    v_scope := public.member_accessible_branch_ids(p_store_id);
    if p_branch_id is not null then
      if not (p_branch_id = any (v_scope)) then
        raise exception 'FORBIDDEN' using errcode = 'P0001';
      end if;
      v_scope := array[p_branch_id];
    end if;

    select coalesce(jsonb_agg(to_jsonb(x) order by x.gross_profit desc), '[]'::jsonb)
    into v_rows
    from (
      select
        z.*,
        row_number() over (order by z.gross_profit desc) as rank
      from (
        select
          ti.name_snapshot as item_name,
          coalesce(c.name, 'General') as category,
          b.name as branch_name,
          t.branch_id,
          sum(ti.quantity)::numeric(14, 3) as units_sold,
          sum(ti.line_total)::numeric(14, 2) as revenue,
          sum(ti.quantity * coalesce(p.cost_price, 0))::numeric(14, 2) as cogs_total,
          (sum(ti.line_total) - sum(ti.quantity * coalesce(p.cost_price, 0)))::numeric(14, 2) as gross_profit,
          case
            when sum(ti.line_total) > 0 then
              round(
                ((sum(ti.line_total) - sum(ti.quantity * coalesce(p.cost_price, 0))) / sum(ti.line_total)) * 100,
                2
              )
            else 0
          end as margin_pct
        from public.transactions t
        join public.transaction_items ti on ti.transaction_id = t.id
        join public.branches b on b.id = t.branch_id
        left join public.products p on p.id = ti.product_id
        left join public.categories c on c.id = p.category_id
        where t.store_id = p_store_id
          and t.status = 'paid'
          and t.branch_id = any (v_scope)
          and t.created_at >= p_start
          and t.created_at < p_end
        group by ti.name_snapshot, coalesce(c.name, 'General'), b.name, t.branch_id
      ) z
    ) x;

    return jsonb_build_object(
      'store_id', p_store_id,
      'branch_ids', to_jsonb(v_scope),
      'start', p_start,
      'end', p_end,
      'rows', v_rows
    );
  end;
  $$;

  create or replace function public.report_dashboard_stats(
    p_store_id uuid,
    p_start timestamptz,
    p_end timestamptz,
    p_branch_id uuid default null,
    p_dead_stock_days int default 30
  )
  returns jsonb
  language plpgsql
  stable
  security definer
  set search_path = public
  as $$
  declare
    v_scope uuid[];
    v_revenue numeric(14, 2);
    v_units numeric(14, 3);
    v_tx_count int;
    v_prev_revenue numeric(14, 2);
    v_prev_units numeric(14, 3);
    v_stock_value numeric(14, 2);
    v_low_stock int;
    v_dead_stock int;
    v_top jsonb;
    v_by_branch jsonb;
    v_by_day jsonb;
    v_duration interval;
    v_prev_start timestamptz;
    v_prev_end timestamptz;
  begin
    if not public.can_view_store_reports(p_store_id) then
      raise exception 'FORBIDDEN' using errcode = 'P0001';
    end if;

    v_scope := public.member_accessible_branch_ids(p_store_id);
    if p_branch_id is not null then
      if not (p_branch_id = any (v_scope)) then
        raise exception 'FORBIDDEN' using errcode = 'P0001';
      end if;
      v_scope := array[p_branch_id];
    end if;

    v_duration := p_end - p_start;
    v_prev_end := p_start;
    v_prev_start := p_start - v_duration;

    select
      coalesce(sum(t.total), 0),
      coalesce(sum(ti.quantity), 0),
      count(distinct t.id)::int
    into v_revenue, v_units, v_tx_count
    from public.transactions t
    left join public.transaction_items ti on ti.transaction_id = t.id
    where t.store_id = p_store_id
      and t.status = 'paid'
      and t.branch_id = any (v_scope)
      and t.created_at >= p_start
      and t.created_at < p_end;

    select coalesce(sum(t.total), 0), coalesce(sum(ti.quantity), 0)
    into v_prev_revenue, v_prev_units
    from public.transactions t
    left join public.transaction_items ti on ti.transaction_id = t.id
    where t.store_id = p_store_id
      and t.status = 'paid'
      and t.branch_id = any (v_scope)
      and t.created_at >= v_prev_start
      and t.created_at < v_prev_end;

    select
      coalesce(sum(p.stock * coalesce(p.cost_price, 0)), 0),
      count(*) filter (where p.stock <= coalesce(p.low_stock_threshold, 0))::int
    into v_stock_value, v_low_stock
    from public.products p
    left join lateral (
      select br.id from public.branches br
      where br.store_id = p.store_id
      order by br.is_primary desc limit 1
    ) pb on true
    where p.store_id = p_store_id
      and p.is_active = true
      and (
        (p.branch_id is not null and p.branch_id = any (v_scope))
        or (p.branch_id is null and pb.id = any (v_scope))
      );

    select count(*)::int into v_dead_stock
    from public.products p
    left join lateral (
      select br.id from public.branches br
      where br.store_id = p.store_id
      order by br.is_primary desc limit 1
    ) pb on true
    where p.store_id = p_store_id
      and p.is_active = true
      and p.stock > 0
      and (
        (p.branch_id is not null and p.branch_id = any (v_scope))
        or (p.branch_id is null and pb.id = any (v_scope))
      )
      and not exists (
        select 1
        from public.transaction_items ti
        join public.transactions t on t.id = ti.transaction_id
        where ti.product_id = p.id
          and t.status = 'paid'
          and t.created_at >= now() - make_interval(days => greatest(p_dead_stock_days, 1))
      );

    select coalesce(jsonb_agg(to_jsonb(x)), '[]'::jsonb)
    into v_top
    from (
      select
        ti.name_snapshot as item_name,
        sum(ti.quantity)::numeric(14, 3) as units_sold,
        sum(ti.line_total)::numeric(14, 2) as revenue
      from public.transactions t
      join public.transaction_items ti on ti.transaction_id = t.id
      where t.store_id = p_store_id
        and t.status = 'paid'
        and t.branch_id = any (v_scope)
        and t.created_at >= p_start
        and t.created_at < p_end
      group by ti.name_snapshot
      order by sum(ti.line_total) desc
      limit 8
    ) x;

    select coalesce(jsonb_agg(to_jsonb(x) order by x.branch_name), '[]'::jsonb)
    into v_by_branch
    from (
      select
        b.name as branch_name,
        b.id as branch_id,
        coalesce(sum(t.total), 0)::numeric(14, 2) as revenue,
        coalesce(sum(ti.quantity), 0)::numeric(14, 3) as units_sold,
        count(distinct t.id)::int as transactions
      from public.branches b
      left join public.transactions t
        on t.branch_id = b.id
      and t.store_id = p_store_id
      and t.status = 'paid'
      and t.created_at >= p_start
      and t.created_at < p_end
      left join public.transaction_items ti on ti.transaction_id = t.id
      where b.store_id = p_store_id
        and b.id = any (v_scope)
      group by b.id, b.name
    ) x;

    select coalesce(jsonb_agg(to_jsonb(x) order by x.day), '[]'::jsonb)
    into v_by_day
    from (
      select
        (t.created_at at time zone 'UTC')::date as day,
        coalesce(sum(t.total), 0)::numeric(14, 2) as revenue,
        coalesce(sum(ti.quantity), 0)::numeric(14, 3) as units_sold
      from public.transactions t
      left join public.transaction_items ti on ti.transaction_id = t.id
      where t.store_id = p_store_id
        and t.status = 'paid'
        and t.branch_id = any (v_scope)
        and t.created_at >= p_start
        and t.created_at < p_end
      group by 1
    ) x;

    return jsonb_build_object(
      'store_id', p_store_id,
      'branch_ids', to_jsonb(v_scope),
      'revenue', v_revenue,
      'units_sold', v_units,
      'transactions', v_tx_count,
      'prev_revenue', v_prev_revenue,
      'prev_units', v_prev_units,
      'revenue_change_pct', case when v_prev_revenue > 0
        then round(((v_revenue - v_prev_revenue) / v_prev_revenue) * 100, 2) else null end,
      'units_change_pct', case when v_prev_units > 0
        then round(((v_units - v_prev_units) / v_prev_units) * 100, 2) else null end,
      'inventory_value', v_stock_value,
      'low_stock_count', v_low_stock,
      'dead_stock_count', v_dead_stock,
      'top_products', v_top,
      'by_branch', v_by_branch,
      'by_day', v_by_day
    );
  end;
  $$;

  grant execute on function public.report_inventory(uuid, uuid, boolean) to authenticated;
  grant execute on function public.report_sales_lines(uuid, timestamptz, timestamptz, uuid) to authenticated;
  grant execute on function public.report_profitability(uuid, timestamptz, timestamptz, uuid) to authenticated;
  grant execute on function public.report_dashboard_stats(uuid, timestamptz, timestamptz, uuid, int) to authenticated;
