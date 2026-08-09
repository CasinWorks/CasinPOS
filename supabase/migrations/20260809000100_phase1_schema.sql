-- FoodPos Phase 1 schema
-- Decisions locked:
--   * Free: 50 paid transactions per calendar month (resets monthly)
--   * Roles: owner, admin, manager, staff (separate)
--   * Team access: invite-only (Owner/Admin create invitations)
--   * Multi-currency, default PHP
--   * Retail/restaurant catalogs are generic & editable by the store

create extension if not exists "pgcrypto";

-- ---------------------------------------------------------------------------
-- Enums
-- ---------------------------------------------------------------------------
create type public.business_type as enum ('restaurant', 'retail');
create type public.store_role as enum ('owner', 'admin', 'manager', 'staff');
create type public.plan_tier as enum ('free', 'premium');
create type public.member_status as enum ('active', 'invited', 'disabled');
create type public.invite_status as enum ('pending', 'accepted', 'revoked', 'expired');
create type public.product_kind as enum ('dish', 'retail_sku');
create type public.table_status as enum ('available', 'occupied', 'reserved');
create type public.booking_status as enum ('confirmed', 'seated', 'cancelled');
create type public.order_status as enum (
  'draft', 'preparing', 'ready', 'served', 'paid', 'voided', 'refunded'
);
create type public.payment_method as enum ('cash', 'gcash', 'maya', 'card', 'other');
create type public.subscription_status as enum ('active', 'past_due', 'canceled');

-- ---------------------------------------------------------------------------
-- Profiles (1:1 auth.users)
-- ---------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  full_name text,
  avatar_url text,
  phone text,
  onboarding_completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Stores (tenant) + monthly freemium counters
-- ---------------------------------------------------------------------------
create table public.stores (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  business_type public.business_type not null,
  owner_id uuid not null references public.profiles (id),
  plan_tier public.plan_tier not null default 'free',
  currency_code text not null default 'PHP',
  currency_symbol text not null default '₱',
  -- Monthly free-tier metering (resets each period)
  billing_period_start date not null default date_trunc('month', now())::date,
  transactions_this_period int not null default 0
    check (transactions_this_period >= 0),
  monthly_transaction_limit int not null default 50
    check (monthly_transaction_limit > 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index stores_owner_id_idx on public.stores (owner_id);

-- ---------------------------------------------------------------------------
-- Branches (free = exactly 1 enforced via trigger)
-- ---------------------------------------------------------------------------
create table public.branches (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  name text not null,
  address text,
  is_primary boolean not null default false,
  created_at timestamptz not null default now(),
  unique (store_id, name)
);

create index branches_store_id_idx on public.branches (store_id);

-- ---------------------------------------------------------------------------
-- Memberships (RBAC)
-- ---------------------------------------------------------------------------
create table public.store_members (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  role public.store_role not null,
  -- NULL branch_ids = all branches; staff often scoped to one
  branch_ids uuid[],
  status public.member_status not null default 'active',
  invited_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  unique (store_id, user_id)
);

create index store_members_user_id_idx on public.store_members (user_id);
create index store_members_store_id_idx on public.store_members (store_id);

-- ---------------------------------------------------------------------------
-- Invitations — Owner/Admin create access; no open join to a store
-- ---------------------------------------------------------------------------
create table public.store_invitations (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  email text not null,
  role public.store_role not null check (role in ('admin', 'manager', 'staff')),
  branch_ids uuid[],
  token text not null unique default encode(gen_random_bytes(24), 'hex'),
  status public.invite_status not null default 'pending',
  invited_by uuid not null references public.profiles (id),
  expires_at timestamptz not null default (now() + interval '7 days'),
  accepted_user_id uuid references public.profiles (id),
  created_at timestamptz not null default now()
);

-- Only one pending invite per email per store
create unique index store_invitations_pending_unique
  on public.store_invitations (store_id, email)
  where status = 'pending';

create index store_invitations_token_idx on public.store_invitations (token);
create index store_invitations_email_idx on public.store_invitations (email);

-- ---------------------------------------------------------------------------
-- Subscriptions
-- ---------------------------------------------------------------------------
create table public.subscriptions (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null unique references public.stores (id) on delete cascade,
  plan_tier public.plan_tier not null default 'free',
  status public.subscription_status not null default 'active',
  provider text not null default 'manual',
  provider_customer_id text,
  provider_subscription_id text,
  current_period_start timestamptz not null default date_trunc('month', now()),
  current_period_end timestamptz not null default (date_trunc('month', now()) + interval '1 month'),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Catalog
-- ---------------------------------------------------------------------------
create table public.categories (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  name text not null,
  sort_order int not null default 0,
  color_token text,
  icon_key text,
  created_at timestamptz not null default now(),
  unique (store_id, name)
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  branch_id uuid references public.branches (id) on delete set null,
  category_id uuid references public.categories (id) on delete set null,
  kind public.product_kind not null,
  name text not null,
  sku text,
  barcode text,
  description text,
  image_path text,
  price numeric(12, 2) not null check (price >= 0),
  cost_price numeric(12, 2) check (cost_price is null or cost_price >= 0),
  weight_label text,
  calories text,
  stock numeric(12, 3),
  low_stock_threshold numeric(12, 3),
  is_popular boolean not null default false,
  is_active boolean not null default true,
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index products_store_id_idx on public.products (store_id);
create index products_barcode_idx on public.products (store_id, barcode);

create table public.product_additions (
  id uuid primary key default gen_random_uuid(),
  product_id uuid not null references public.products (id) on delete cascade,
  name text not null,
  price numeric(12, 2) not null default 0 check (price >= 0),
  is_active boolean not null default true
);

-- ---------------------------------------------------------------------------
-- Restaurant floor & bookings
-- ---------------------------------------------------------------------------
create table public.floor_tables (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  number text not null,
  seats int not null default 2 check (seats > 0),
  section text not null default 'Main Hall',
  status public.table_status not null default 'available',
  guest_count int,
  created_at timestamptz not null default now(),
  unique (branch_id, number)
);

create table public.bookings (
  id uuid primary key default gen_random_uuid(),
  branch_id uuid not null references public.branches (id) on delete cascade,
  table_id uuid references public.floor_tables (id) on delete set null,
  customer_name text not null,
  phone text,
  guests int not null default 2 check (guests > 0),
  starts_at timestamptz not null,
  status public.booking_status not null default 'confirmed',
  notes text,
  created_at timestamptz not null default now()
);

-- ---------------------------------------------------------------------------
-- Commerce
-- ---------------------------------------------------------------------------
create table public.transactions (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  branch_id uuid not null references public.branches (id),
  order_no text not null,
  business_type public.business_type not null,
  status public.order_status not null default 'draft',
  subtotal numeric(12, 2) not null default 0,
  tax numeric(12, 2) not null default 0,
  total numeric(12, 2) not null default 0,
  currency_code text not null default 'PHP',
  payment_method public.payment_method,
  cash_received numeric(12, 2),
  change_given numeric(12, 2),
  staff_id uuid not null references public.profiles (id),
  table_id uuid references public.floor_tables (id),
  customer_name text,
  notes text,
  paid_at timestamptz,
  created_at timestamptz not null default now(),
  unique (store_id, order_no)
);

create index transactions_store_paid_idx
  on public.transactions (store_id, paid_at desc)
  where status = 'paid';

create index transactions_staff_paid_idx
  on public.transactions (staff_id, paid_at desc)
  where status = 'paid';

create table public.transaction_items (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions (id) on delete cascade,
  product_id uuid references public.products (id) on delete set null,
  name_snapshot text not null,
  quantity numeric(12, 3) not null check (quantity > 0),
  unit_price numeric(12, 2) not null,
  additions jsonb not null default '[]'::jsonb,
  notes text,
  line_total numeric(12, 2) not null
);

-- ---------------------------------------------------------------------------
-- Helpers: membership & role checks
-- ---------------------------------------------------------------------------
create or replace function public.is_store_member(p_store_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.store_members m
    where m.store_id = p_store_id
      and m.user_id = auth.uid()
      and m.status = 'active'
  );
$$;

create or replace function public.member_role(p_store_id uuid)
returns public.store_role
language sql
stable
security definer
set search_path = public
as $$
  select m.role from public.store_members m
  where m.store_id = p_store_id
    and m.user_id = auth.uid()
    and m.status = 'active'
  limit 1;
$$;

create or replace function public.has_store_role(
  p_store_id uuid,
  p_roles public.store_role[]
)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.store_members m
    where m.store_id = p_store_id
      and m.user_id = auth.uid()
      and m.status = 'active'
      and m.role = any (p_roles)
  );
$$;

create or replace function public.store_id_for_branch(p_branch_id uuid)
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select b.store_id from public.branches b where b.id = p_branch_id;
$$;

-- ---------------------------------------------------------------------------
-- Auto profile on signup
-- ---------------------------------------------------------------------------
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, avatar_url)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', new.email),
    new.raw_user_meta_data->>'avatar_url'
  );
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ---------------------------------------------------------------------------
-- Create store RPC — first user becomes owner + primary branch + subscription
-- Open signup creates a *new* store only; joining an existing store requires invite.
-- ---------------------------------------------------------------------------
create or replace function public.create_store(
  p_name text,
  p_business_type public.business_type,
  p_currency_code text default 'PHP',
  p_currency_symbol text default '₱',
  p_primary_branch_name text default 'Main'
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
  v_uid uuid := auth.uid();
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if length(trim(p_name)) < 1 then
    raise exception 'STORE_NAME_REQUIRED';
  end if;

  insert into public.stores (
    name, business_type, owner_id, currency_code, currency_symbol
  ) values (
    trim(p_name), p_business_type, v_uid,
    coalesce(nullif(trim(p_currency_code), ''), 'PHP'),
    coalesce(nullif(trim(p_currency_symbol), ''), '₱')
  )
  returning id into v_store_id;

  insert into public.branches (store_id, name, is_primary)
  values (v_store_id, coalesce(nullif(trim(p_primary_branch_name), ''), 'Main'), true);

  insert into public.store_members (store_id, user_id, role, status)
  values (v_store_id, v_uid, 'owner', 'active');

  insert into public.subscriptions (store_id, plan_tier, status)
  values (v_store_id, 'free', 'active');

  return v_store_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Invite teammate (Owner / Admin only) — cannot invite as owner
-- ---------------------------------------------------------------------------
create or replace function public.create_store_invitation(
  p_store_id uuid,
  p_email text,
  p_role public.store_role,
  p_branch_ids uuid[] default null
)
returns public.store_invitations
language plpgsql
security definer
set search_path = public
as $$
declare
  v_row public.store_invitations;
begin
  if not public.has_store_role(p_store_id, array['owner', 'admin']::public.store_role[]) then
    raise exception 'FORBIDDEN';
  end if;

  if p_role = 'owner' then
    raise exception 'CANNOT_INVITE_OWNER';
  end if;

  -- Admin may invite manager/staff only (not another admin) unless caller is owner
  if public.member_role(p_store_id) = 'admin' and p_role = 'admin' then
    raise exception 'ADMIN_CANNOT_INVITE_ADMIN';
  end if;

  insert into public.store_invitations (
    store_id, email, role, branch_ids, invited_by
  ) values (
    p_store_id, lower(trim(p_email)), p_role, p_branch_ids, auth.uid()
  )
  returning * into v_row;

  return v_row;
end;
$$;

-- ---------------------------------------------------------------------------
-- Accept invitation — links auth user to store_members
-- ---------------------------------------------------------------------------
create or replace function public.accept_store_invitation(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv public.store_invitations;
  v_uid uuid := auth.uid();
  v_email text;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select email into v_email from auth.users where id = v_uid;

  select * into v_inv
  from public.store_invitations
  where token = p_token
    and status = 'pending'
    and expires_at > now()
  for update;

  if not found then
    raise exception 'INVITE_INVALID_OR_EXPIRED';
  end if;

  if lower(v_email) <> lower(v_inv.email) then
    raise exception 'INVITE_EMAIL_MISMATCH';
  end if;

  insert into public.store_members (
    store_id, user_id, role, branch_ids, status, invited_by
  ) values (
    v_inv.store_id, v_uid, v_inv.role, v_inv.branch_ids, 'active', v_inv.invited_by
  )
  on conflict (store_id, user_id) do update
    set role = excluded.role,
        branch_ids = excluded.branch_ids,
        status = 'active';

  update public.store_invitations
  set status = 'accepted', accepted_user_id = v_uid
  where id = v_inv.id;

  return v_inv.store_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Monthly freemium: rollover period + gate paid transactions
-- ---------------------------------------------------------------------------
create or replace function public.ensure_billing_period(p_store_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_start date;
begin
  select billing_period_start into v_start
  from public.stores where id = p_store_id for update;

  if v_start is distinct from date_trunc('month', now())::date then
    update public.stores
    set billing_period_start = date_trunc('month', now())::date,
        transactions_this_period = 0,
        updated_at = now()
    where id = p_store_id;
  end if;
end;
$$;

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

create or replace function public.on_transaction_paid()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'paid'
     and (old.status is distinct from 'paid') then
    perform public.assert_can_complete_sale(new.store_id);

    update public.stores
    set transactions_this_period = transactions_this_period + 1,
        updated_at = now()
    where id = new.store_id;

    if new.paid_at is null then
      new.paid_at := now();
    end if;
  end if;
  return new;
end;
$$;

create trigger transactions_paid_metering
  before update of status on public.transactions
  for each row execute function public.on_transaction_paid();

-- Also meter inserts that are created already paid
create or replace function public.on_transaction_insert_paid()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.status = 'paid' then
    perform public.assert_can_complete_sale(new.store_id);
    update public.stores
    set transactions_this_period = transactions_this_period + 1,
        updated_at = now()
    where id = new.store_id;
    if new.paid_at is null then
      new.paid_at := now();
    end if;
  end if;
  return new;
end;
$$;

create trigger transactions_insert_paid_metering
  before insert on public.transactions
  for each row execute function public.on_transaction_insert_paid();

-- ---------------------------------------------------------------------------
-- Branch limit: free stores may only have 1 branch
-- ---------------------------------------------------------------------------
create or replace function public.enforce_branch_limit()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tier public.plan_tier;
  v_count int;
begin
  select plan_tier into v_tier from public.stores where id = new.store_id;
  if v_tier = 'free' then
    select count(*) into v_count from public.branches where store_id = new.store_id;
    if tg_op = 'INSERT' and v_count >= 1 then
      raise exception 'PREMIUM_REQUIRED_FOR_MULTI_BRANCH';
    end if;
  end if;
  return new;
end;
$$;

create trigger branches_free_limit
  before insert on public.branches
  for each row execute function public.enforce_branch_limit();

-- ---------------------------------------------------------------------------
-- Staff personal analytics helper (today/week/month/quarter/year)
-- ---------------------------------------------------------------------------
create or replace function public.staff_personal_sales(
  p_store_id uuid,
  p_period text default 'today'
)
returns table (
  period text,
  transaction_count bigint,
  gross_sales numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_start timestamptz;
  v_role public.store_role;
begin
  if not public.is_store_member(p_store_id) then
    raise exception 'FORBIDDEN';
  end if;

  v_role := public.member_role(p_store_id);

  v_start := case p_period
    when 'today' then date_trunc('day', now())
    when 'week' then date_trunc('week', now())
    when 'month' then date_trunc('month', now())
    when 'quarter' then date_trunc('quarter', now())
    when 'year' then date_trunc('year', now())
    else date_trunc('day', now())
  end;

  return query
  select
    p_period,
    count(*)::bigint,
    coalesce(sum(t.total), 0)
  from public.transactions t
  where t.store_id = p_store_id
    and t.status = 'paid'
    and t.paid_at >= v_start
    and (
      v_role in ('owner', 'admin', 'manager')
      or t.staff_id = auth.uid()
    );
end;
$$;

-- Store / branch analytics for manager+ (optional branch filter; aggregate if null + premium)
create or replace function public.store_sales_summary(
  p_store_id uuid,
  p_period text default 'month',
  p_branch_id uuid default null,
  p_aggregate boolean default false
)
returns table (
  period text,
  branch_id uuid,
  transaction_count bigint,
  gross_sales numeric
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_start timestamptz;
  v_tier public.plan_tier;
begin
  if not public.has_store_role(
    p_store_id,
    array['owner', 'admin', 'manager']::public.store_role[]
  ) then
    raise exception 'FORBIDDEN';
  end if;

  select plan_tier into v_tier from public.stores where id = p_store_id;

  if p_aggregate and v_tier <> 'premium' then
    raise exception 'PREMIUM_REQUIRED_FOR_AGGREGATE';
  end if;

  v_start := case p_period
    when 'today' then date_trunc('day', now())
    when 'week' then date_trunc('week', now())
    when 'month' then date_trunc('month', now())
    when 'quarter' then date_trunc('quarter', now())
    when 'year' then date_trunc('year', now())
    else date_trunc('month', now())
  end;

  if p_aggregate then
    return query
    select p_period, null::uuid, count(*)::bigint, coalesce(sum(t.total), 0)
    from public.transactions t
    where t.store_id = p_store_id
      and t.status = 'paid'
      and t.paid_at >= v_start;
  else
    return query
    select p_period, t.branch_id, count(*)::bigint, coalesce(sum(t.total), 0)
    from public.transactions t
    where t.store_id = p_store_id
      and t.status = 'paid'
      and t.paid_at >= v_start
      and (p_branch_id is null or t.branch_id = p_branch_id)
    group by t.branch_id;
  end if;
end;
$$;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.profiles enable row level security;
alter table public.stores enable row level security;
alter table public.branches enable row level security;
alter table public.store_members enable row level security;
alter table public.store_invitations enable row level security;
alter table public.subscriptions enable row level security;
alter table public.categories enable row level security;
alter table public.products enable row level security;
alter table public.product_additions enable row level security;
alter table public.floor_tables enable row level security;
alter table public.bookings enable row level security;
alter table public.transactions enable row level security;
alter table public.transaction_items enable row level security;

-- Profiles
create policy profiles_select_self_or_teammates on public.profiles
  for select using (
    id = auth.uid()
    or exists (
      select 1 from public.store_members me
      join public.store_members them
        on me.store_id = them.store_id
      where me.user_id = auth.uid()
        and them.user_id = profiles.id
        and me.status = 'active'
        and them.status = 'active'
    )
  );

create policy profiles_update_self on public.profiles
  for update using (id = auth.uid());

-- Stores
create policy stores_select_member on public.stores
  for select using (public.is_store_member(id));

create policy stores_update_owner_admin on public.stores
  for update using (
    public.has_store_role(id, array['owner', 'admin']::public.store_role[])
  );

-- Branches
create policy branches_select_member on public.branches
  for select using (public.is_store_member(store_id));

create policy branches_write_owner_admin on public.branches
  for all using (
    public.has_store_role(store_id, array['owner', 'admin']::public.store_role[])
  );

-- Members
create policy members_select_member on public.store_members
  for select using (public.is_store_member(store_id));

create policy members_write_owner_admin on public.store_members
  for all using (
    public.has_store_role(store_id, array['owner', 'admin']::public.store_role[])
  );

-- Invitations: owner/admin manage; invitee can read own pending by email match via RPC prefer
create policy invitations_select_managers on public.store_invitations
  for select using (
    public.has_store_role(store_id, array['owner', 'admin']::public.store_role[])
  );

create policy invitations_write_managers on public.store_invitations
  for all using (
    public.has_store_role(store_id, array['owner', 'admin']::public.store_role[])
  );

-- Subscriptions
create policy subscriptions_select_member on public.subscriptions
  for select using (public.is_store_member(store_id));

create policy subscriptions_update_owner on public.subscriptions
  for update using (
    public.has_store_role(store_id, array['owner']::public.store_role[])
  );

-- Catalog
create policy categories_select_member on public.categories
  for select using (public.is_store_member(store_id));

create policy categories_write_managers on public.categories
  for all using (
    public.has_store_role(
      store_id,
      array['owner', 'admin', 'manager']::public.store_role[]
    )
  );

create policy products_select_member on public.products
  for select using (public.is_store_member(store_id));

create policy products_write_managers on public.products
  for all using (
    public.has_store_role(
      store_id,
      array['owner', 'admin', 'manager']::public.store_role[]
    )
  );

create policy product_additions_select on public.product_additions
  for select using (
    exists (
      select 1 from public.products p
      where p.id = product_id and public.is_store_member(p.store_id)
    )
  );

create policy product_additions_write on public.product_additions
  for all using (
    exists (
      select 1 from public.products p
      where p.id = product_id
        and public.has_store_role(
          p.store_id,
          array['owner', 'admin', 'manager']::public.store_role[]
        )
    )
  );

-- Floor / bookings
create policy floor_tables_select on public.floor_tables
  for select using (public.is_store_member(public.store_id_for_branch(branch_id)));

create policy floor_tables_write on public.floor_tables
  for all using (
    public.has_store_role(
      public.store_id_for_branch(branch_id),
      array['owner', 'admin', 'manager']::public.store_role[]
    )
  );

create policy bookings_select on public.bookings
  for select using (public.is_store_member(public.store_id_for_branch(branch_id)));

create policy bookings_write on public.bookings
  for all using (
    public.has_store_role(
      public.store_id_for_branch(branch_id),
      array['owner', 'admin', 'manager']::public.store_role[]
    )
  );

-- Transactions: members can insert/select; staff see own for detailed audit via app filter;
-- managers+ see all. RLS allows member read of store transactions (UI filters personal).
create policy transactions_select_member on public.transactions
  for select using (public.is_store_member(store_id));

create policy transactions_insert_member on public.transactions
  for insert with check (
    public.is_store_member(store_id) and staff_id = auth.uid()
  );

create policy transactions_update_member on public.transactions
  for update using (public.is_store_member(store_id));

create policy transaction_items_select on public.transaction_items
  for select using (
    exists (
      select 1 from public.transactions t
      where t.id = transaction_id and public.is_store_member(t.store_id)
    )
  );

create policy transaction_items_write on public.transaction_items
  for all using (
    exists (
      select 1 from public.transactions t
      where t.id = transaction_id and public.is_store_member(t.store_id)
    )
  );

-- Grants for authenticated
grant usage on schema public to authenticated;
grant select, update on public.profiles to authenticated;
grant select, update on public.stores to authenticated;
grant select, insert, update, delete on public.branches to authenticated;
grant select, insert, update, delete on public.store_members to authenticated;
grant select, insert, update, delete on public.store_invitations to authenticated;
grant select, update on public.subscriptions to authenticated;
grant select, insert, update, delete on public.categories to authenticated;
grant select, insert, update, delete on public.products to authenticated;
grant select, insert, update, delete on public.product_additions to authenticated;
grant select, insert, update, delete on public.floor_tables to authenticated;
grant select, insert, update, delete on public.bookings to authenticated;
grant select, insert, update on public.transactions to authenticated;
grant select, insert, update, delete on public.transaction_items to authenticated;

grant execute on function public.create_store(text, public.business_type, text, text, text) to authenticated;
grant execute on function public.create_store_invitation(uuid, text, public.store_role, uuid[]) to authenticated;
grant execute on function public.accept_store_invitation(text) to authenticated;
grant execute on function public.staff_personal_sales(uuid, text) to authenticated;
grant execute on function public.store_sales_summary(uuid, text, uuid, boolean) to authenticated;
