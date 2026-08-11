-- Platform ops: CasinPOS SaaS admins can list tenants, set plan, suspend stores.

alter table public.profiles
  add column if not exists is_platform_admin boolean not null default false;

alter table public.stores
  add column if not exists suspended_at timestamptz,
  add column if not exists suspension_reason text;

create index if not exists stores_suspended_at_idx
  on public.stores (suspended_at)
  where suspended_at is not null;

create or replace function public.is_platform_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (select p.is_platform_admin from public.profiles p where p.id = auth.uid()),
    false
  );
$$;

grant execute on function public.is_platform_admin() to authenticated;

-- Promote / demote by email (run in SQL Editor; also callable by existing platform admins).
create or replace function public.platform_set_admin_by_email(
  p_email text,
  p_is_admin boolean default true
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid;
  v_caller_ok boolean := public.is_platform_admin();
  v_as_sql boolean := current_user in ('postgres', 'supabase_admin');
begin
  -- SQL Editor (postgres) can always promote. App: existing admin, or first self-bootstrap.
  if not v_as_sql and not v_caller_ok then
    if exists (select 1 from public.profiles where is_platform_admin) then
      raise exception 'FORBIDDEN' using errcode = 'P0001';
    end if;
    if lower(trim(p_email)) is distinct from lower(trim(coalesce(auth.jwt() ->> 'email', ''))) then
      raise exception 'FORBIDDEN' using errcode = 'P0001';
    end if;
  end if;

  select id into v_uid
  from auth.users
  where lower(email) = lower(trim(p_email))
  limit 1;

  if v_uid is null then
    raise exception 'USER_NOT_FOUND' using errcode = 'P0001';
  end if;

  update public.profiles
  set is_platform_admin = p_is_admin, updated_at = now()
  where id = v_uid;

  return jsonb_build_object(
    'ok', true,
    'user_id', v_uid,
    'email', lower(trim(p_email)),
    'is_platform_admin', p_is_admin
  );
end;
$$;

grant execute on function public.platform_set_admin_by_email(text, boolean) to authenticated;

create or replace function public.assert_can_complete_sale(p_store_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store public.stores%rowtype;
begin
  perform public.ensure_billing_period(p_store_id);

  select * into v_store from public.stores where id = p_store_id;

  if v_store.suspended_at is not null then
    raise exception 'STORE_SUSPENDED'
      using errcode = 'P0001',
            detail = coalesce(v_store.suspension_reason, 'This store is suspended. Contact support.');
  end if;

  if v_store.plan_tier = 'free'
     and v_store.transactions_this_period >= v_store.monthly_transaction_limit then
    raise exception 'FREE_MONTHLY_LIMIT_REACHED'
      using errcode = 'P0001',
            detail = format(
              'Free plan allows %s paid transactions per month. Upgrade to Premium.',
              v_store.monthly_transaction_limit
            );
  end if;
end;
$$;

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
    case when p_plan_tier = 'premium' then 100000 else 50 end
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

grant execute on function public.platform_set_store_plan(uuid, public.plan_tier, int) to authenticated;

create or replace function public.platform_set_store_suspended(
  p_store_id uuid,
  p_suspended boolean,
  p_reason text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  if not exists (select 1 from public.stores where id = p_store_id) then
    raise exception 'STORE_NOT_FOUND' using errcode = 'P0001';
  end if;

  update public.stores
  set
    suspended_at = case when p_suspended then now() else null end,
    suspension_reason = case
      when p_suspended then nullif(trim(coalesce(p_reason, '')), '')
      else null
    end,
    updated_at = now()
  where id = p_store_id;

  return jsonb_build_object(
    'ok', true,
    'store_id', p_store_id,
    'suspended', p_suspended
  );
end;
$$;

grant execute on function public.platform_set_store_suspended(uuid, boolean, text) to authenticated;

-- Platform admins can read all stores for ops UI (optional direct select).
drop policy if exists stores_select_platform_admin on public.stores;
create policy stores_select_platform_admin on public.stores
  for select to authenticated
  using (public.is_platform_admin());
