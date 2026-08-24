-- Service catalog, quotes, bookings, conversion RPCs, RLS.
-- Conversion (locked): Accept quote always creates a service_bookings row.
-- Deposit is optional on accept and writes one transactions row.
-- Remainder is collected later on that same transaction.

-- ---------------------------------------------------------------------------
-- Catalog (fixed-price). No stock.
-- ---------------------------------------------------------------------------
create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  branch_id uuid references public.branches (id) on delete set null,
  category_id uuid references public.categories (id) on delete set null,
  name text not null,
  description text,
  duration_minutes int not null default 60 check (duration_minutes > 0),
  price numeric(12, 2) not null check (price >= 0),
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists services_store_id_idx on public.services (store_id);

create table if not exists public.service_addons (
  id uuid primary key default gen_random_uuid(),
  service_id uuid not null references public.services (id) on delete cascade,
  name text not null,
  price numeric(12, 2) not null default 0 check (price >= 0),
  is_active boolean not null default true
);

-- ---------------------------------------------------------------------------
-- Quotes (freeform lines; not FK to services)
-- ---------------------------------------------------------------------------
create table if not exists public.quotes (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  branch_id uuid not null references public.branches (id),
  client_name text not null,
  client_phone text,
  client_email text,
  job_description text,
  estimated_total numeric(12, 2) not null default 0 check (estimated_total >= 0),
  status public.quote_status not null default 'draft',
  valid_until date,
  share_token text unique,
  sent_at timestamptz,
  accepted_at timestamptz,
  accepted_booking_id uuid,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists quotes_store_id_idx on public.quotes (store_id, created_at desc);
create unique index if not exists quotes_share_token_uidx on public.quotes (share_token)
  where share_token is not null;

create table if not exists public.quote_line_items (
  id uuid primary key default gen_random_uuid(),
  quote_id uuid not null references public.quotes (id) on delete cascade,
  sort_order int not null default 0,
  description text not null,
  quantity numeric(12, 3) not null default 1 check (quantity > 0),
  unit_price numeric(12, 2) not null default 0 check (unit_price >= 0)
);

-- ---------------------------------------------------------------------------
-- Service bookings (separate from restaurant public.bookings)
-- ---------------------------------------------------------------------------
create table if not exists public.service_bookings (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  branch_id uuid not null references public.branches (id),
  quote_id uuid references public.quotes (id) on delete set null,
  client_name text not null,
  client_phone text,
  scheduled_at timestamptz not null,
  status public.service_booking_status not null default 'upcoming',
  notes text,
  transaction_id uuid references public.transactions (id) on delete set null,
  created_by uuid references public.profiles (id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists service_bookings_store_sched_idx
  on public.service_bookings (store_id, scheduled_at);

create table if not exists public.service_booking_items (
  id uuid primary key default gen_random_uuid(),
  booking_id uuid not null references public.service_bookings (id) on delete cascade,
  service_id uuid references public.services (id) on delete set null,
  description text not null,
  quantity numeric(12, 3) not null default 1 check (quantity > 0),
  unit_price numeric(12, 2) not null default 0 check (unit_price >= 0)
);

create table if not exists public.transaction_payments (
  id uuid primary key default gen_random_uuid(),
  transaction_id uuid not null references public.transactions (id) on delete cascade,
  amount numeric(12, 2) not null check (amount > 0),
  payment_method public.payment_method not null,
  kind public.payment_kind not null default 'full',
  paid_at timestamptz not null default now(),
  created_by uuid references public.profiles (id)
);

alter table public.transactions
  drop constraint if exists transactions_service_booking_id_fkey;
alter table public.transactions
  add constraint transactions_service_booking_id_fkey
  foreign key (service_booking_id) references public.service_bookings (id) on delete set null;

alter table public.transactions
  drop constraint if exists transactions_quote_id_fkey;
alter table public.transactions
  add constraint transactions_quote_id_fkey
  foreign key (quote_id) references public.quotes (id) on delete set null;

alter table public.quotes
  drop constraint if exists quotes_accepted_booking_id_fkey;
alter table public.quotes
  add constraint quotes_accepted_booking_id_fkey
  foreign key (accepted_booking_id) references public.service_bookings (id) on delete set null;

alter table public.stores drop constraint if exists stores_service_pricing_mode_chk;
alter table public.stores
  add constraint stores_service_pricing_mode_chk
  check (
    business_type = 'service' or service_pricing_mode is null
  );

create or replace function public.stores_fill_service_pricing_mode()
returns trigger
language plpgsql
as $$
begin
  if new.business_type = 'service' and new.service_pricing_mode is null then
    if new.franchisor_store_id is not null then
      select service_pricing_mode into new.service_pricing_mode
      from public.stores
      where id = new.franchisor_store_id;
    end if;
    new.service_pricing_mode := coalesce(new.service_pricing_mode, 'fixed');
  end if;
  if new.business_type <> 'service' then
    new.service_pricing_mode := null;
  end if;
  return new;
end;
$$;

drop trigger if exists stores_fill_service_pricing_mode on public.stores;
create trigger stores_fill_service_pricing_mode
  before insert or update on public.stores
  for each row
  execute function public.stores_fill_service_pricing_mode();

-- ---------------------------------------------------------------------------
-- create_store: optional pricing mode for service stores
-- ---------------------------------------------------------------------------
drop function if exists public.create_store(text, public.business_type, text, text, text);

create function public.create_store(
  p_name text,
  p_business_type public.business_type,
  p_currency_code text default 'PHP',
  p_currency_symbol text default '₱',
  p_primary_branch_name text default 'Main',
  p_service_pricing_mode public.service_pricing_mode default null
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

  insert into public.stores (
    name, business_type, owner_id, currency_code, currency_symbol, service_pricing_mode
  ) values (
    trim(p_name), p_business_type, v_uid,
    coalesce(nullif(trim(p_currency_code), ''), 'PHP'),
    coalesce(nullif(trim(p_currency_symbol), ''), '₱'),
    v_mode
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

grant execute on function public.create_store(
  text, public.business_type, text, text, text, public.service_pricing_mode
) to authenticated;

-- ---------------------------------------------------------------------------
-- Internal: one transaction for a service booking (deposit / full / remainder)
-- ---------------------------------------------------------------------------
create or replace function public._service_insert_transaction(
  p_store_id uuid,
  p_branch_id uuid,
  p_booking_id uuid,
  p_quote_id uuid,
  p_client_name text,
  p_client_phone text,
  p_total numeric,
  p_amount_paid numeric,
  p_payment_method public.payment_method,
  p_kind public.payment_kind,
  p_staff_id uuid
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_txn_id uuid := gen_random_uuid();
  v_order_no text;
  v_due numeric;
  v_state public.payment_state;
  v_paid numeric;
begin
  v_paid := greatest(p_amount_paid, 0);
  if v_paid > p_total then
    v_paid := p_total;
  end if;
  v_due := greatest(p_total - v_paid, 0);
  v_state := case
    when v_due <= 0 then 'paid'::public.payment_state
    when v_paid > 0 then 'deposit_paid'::public.payment_state
    else 'unpaid'::public.payment_state
  end;
  v_order_no := '#CP-' || (floor(extract(epoch from now()) * 1000)::bigint % 1000000)::text;

  insert into public.transactions (
    id, store_id, branch_id, order_no, business_type, status,
    subtotal, tax, total, currency_code, payment_method, staff_id,
    customer_name, client_phone, paid_at,
    amount_paid, balance_due, payment_state,
    service_booking_id, quote_id
  )
  select
    v_txn_id, p_store_id, p_branch_id, v_order_no, 'service',
    'paid',
    p_total, 0, p_total, s.currency_code, p_payment_method, p_staff_id,
    p_client_name, p_client_phone, now(),
    v_paid, v_due, v_state,
    p_booking_id, p_quote_id
  from public.stores s
  where s.id = p_store_id;

  insert into public.transaction_items (
    transaction_id, product_id, name_snapshot, quantity, unit_price, line_total, additions
  )
  select
    v_txn_id, null, i.description, i.quantity, i.unit_price,
    round(i.quantity * i.unit_price, 2), '[]'::jsonb
  from public.service_booking_items i
  where i.booking_id = p_booking_id;

  if v_paid > 0 then
    insert into public.transaction_payments (
      transaction_id, amount, payment_method, kind, created_by
    ) values (
      v_txn_id, v_paid, p_payment_method, p_kind, p_staff_id
    );
  end if;

  update public.service_bookings
  set transaction_id = v_txn_id, updated_at = now()
  where id = p_booking_id;

  return v_txn_id;
end;
$$;

-- ---------------------------------------------------------------------------
-- Send quote (draft/sent → sent) + share token
-- ---------------------------------------------------------------------------
create or replace function public.send_service_quote(p_quote_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_q public.quotes;
begin
  select * into v_q from public.quotes where id = p_quote_id;
  if v_q.id is null then
    raise exception 'QUOTE_NOT_FOUND' using errcode = 'P0001';
  end if;
  if not public.is_store_member(v_q.store_id) then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
  if v_q.status not in ('draft', 'sent') then
    raise exception 'QUOTE_NOT_SENDABLE' using errcode = 'P0001';
  end if;

  update public.quotes
  set
    status = 'sent',
    sent_at = now(),
    share_token = coalesce(share_token, encode(extensions.gen_random_bytes(16), 'hex')),
    valid_until = case
      when valid_until is null or valid_until < current_date
        then (timezone('utc', now()) + interval '14 days')::date
      else valid_until
    end,
    updated_at = now()
  where id = p_quote_id
  returning * into v_q;

  return jsonb_build_object(
    'id', v_q.id,
    'status', v_q.status,
    'share_token', v_q.share_token,
    'valid_until', v_q.valid_until
  );
end;
$$;

grant execute on function public.send_service_quote(uuid) to authenticated;

-- ---------------------------------------------------------------------------
-- Accept quote → always a service booking. Optional deposit → one transaction.
-- ---------------------------------------------------------------------------
create or replace function public.accept_service_quote(
  p_quote_id uuid,
  p_scheduled_at timestamptz,
  p_deposit_amount numeric default 0,
  p_payment_method public.payment_method default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_q public.quotes;
  v_uid uuid := auth.uid();
  v_booking_id uuid;
  v_txn_id uuid;
  v_deposit numeric := coalesce(p_deposit_amount, 0);
  v_total numeric;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED' using errcode = 'P0001';
  end if;

  select * into v_q from public.quotes where id = p_quote_id for update;
  if v_q.id is null then
    raise exception 'QUOTE_NOT_FOUND' using errcode = 'P0001';
  end if;
  if not public.is_store_member(v_q.store_id) then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
  if v_q.status = 'accepted' and v_q.accepted_booking_id is not null then
    raise exception 'QUOTE_ALREADY_ACCEPTED' using errcode = 'P0001';
  end if;
  if v_q.status not in ('sent', 'draft') then
    raise exception 'QUOTE_NOT_ACCEPTABLE' using errcode = 'P0001';
  end if;
  if p_scheduled_at is null then
    raise exception 'SCHEDULE_REQUIRED' using errcode = 'P0001';
  end if;

  v_total := coalesce(v_q.estimated_total, 0);
  if v_deposit < 0 then
    raise exception 'DEPOSIT_INVALID' using errcode = 'P0001';
  end if;
  if v_deposit > v_total then
    v_deposit := v_total;
  end if;

  insert into public.service_bookings (
    store_id, branch_id, quote_id, client_name, client_phone,
    scheduled_at, status, created_by
  ) values (
    v_q.store_id, v_q.branch_id, v_q.id, v_q.client_name, v_q.client_phone,
    p_scheduled_at, 'upcoming', v_uid
  )
  returning id into v_booking_id;

  insert into public.service_booking_items (
    booking_id, description, quantity, unit_price
  )
  select v_booking_id, description, quantity, unit_price
  from public.quote_line_items
  where quote_id = v_q.id
  order by sort_order;

  if not exists (
    select 1 from public.service_booking_items where booking_id = v_booking_id
  ) then
    insert into public.service_booking_items (
      booking_id, description, quantity, unit_price
    ) values (
      v_booking_id,
      coalesce(nullif(trim(v_q.job_description), ''), 'Service'),
      1,
      v_total
    );
  end if;

  if v_deposit > 0 then
    if p_payment_method is null then
      raise exception 'PAYMENT_METHOD_REQUIRED' using errcode = 'P0001';
    end if;
    v_txn_id := public._service_insert_transaction(
      v_q.store_id, v_q.branch_id, v_booking_id, v_q.id,
      v_q.client_name, v_q.client_phone, v_total, v_deposit,
      p_payment_method,
      case when v_deposit >= v_total then 'full'::public.payment_kind
           else 'deposit'::public.payment_kind end,
      v_uid
    );
  end if;

  update public.quotes
  set
    status = 'accepted',
    accepted_at = now(),
    accepted_booking_id = v_booking_id,
    updated_at = now()
  where id = v_q.id;

  return jsonb_build_object(
    'booking_id', v_booking_id,
    'transaction_id', v_txn_id,
    'quote_id', v_q.id,
    'deposit', v_deposit,
    'balance_due', greatest(v_total - v_deposit, 0)
  );
end;
$$;

grant execute on function public.accept_service_quote(
  uuid, timestamptz, numeric, public.payment_method
) to authenticated;

-- ---------------------------------------------------------------------------
-- Catalog POS: booking with optional deposit (quote_id null)
-- ---------------------------------------------------------------------------
create or replace function public.create_catalog_service_booking(
  p_store_id uuid,
  p_client_name text,
  p_client_phone text,
  p_scheduled_at timestamptz,
  p_items jsonb,
  p_deposit_amount numeric default 0,
  p_payment_method public.payment_method default null,
  p_notes text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_branch uuid;
  v_booking_id uuid;
  v_txn_id uuid;
  v_deposit numeric := coalesce(p_deposit_amount, 0);
  v_total numeric := 0;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED' using errcode = 'P0001';
  end if;
  if not public.is_store_member(p_store_id) then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
  if p_scheduled_at is null then
    raise exception 'SCHEDULE_REQUIRED' using errcode = 'P0001';
  end if;
  if length(trim(coalesce(p_client_name, ''))) < 1 then
    raise exception 'CLIENT_NAME_REQUIRED' using errcode = 'P0001';
  end if;

  select id into v_branch
  from public.branches
  where store_id = p_store_id and is_primary
  limit 1;
  if v_branch is null then
    select id into v_branch from public.branches where store_id = p_store_id limit 1;
  end if;
  if v_branch is null then
    raise exception 'BRANCH_NOT_FOUND' using errcode = 'P0001';
  end if;

  insert into public.service_bookings (
    store_id, branch_id, quote_id, client_name, client_phone,
    scheduled_at, status, notes, created_by
  ) values (
    p_store_id, v_branch, null, trim(p_client_name), nullif(trim(p_client_phone), ''),
    p_scheduled_at, 'upcoming', p_notes, v_uid
  )
  returning id into v_booking_id;

  insert into public.service_booking_items (
    booking_id, service_id, description, quantity, unit_price
  )
  select
    v_booking_id,
    nullif(e->>'service_id', '')::uuid,
    coalesce(nullif(trim(e->>'description'), ''), 'Service'),
    greatest(coalesce((e->>'quantity')::numeric, 1), 0.001),
    greatest(coalesce((e->>'unit_price')::numeric, 0), 0)
  from jsonb_array_elements(coalesce(p_items, '[]'::jsonb)) e;

  select coalesce(sum(quantity * unit_price), 0)
  into v_total
  from public.service_booking_items
  where booking_id = v_booking_id;

  if v_deposit < 0 then
    raise exception 'DEPOSIT_INVALID' using errcode = 'P0001';
  end if;
  if v_deposit > v_total then
    v_deposit := v_total;
  end if;

  if v_deposit > 0 then
    if p_payment_method is null then
      raise exception 'PAYMENT_METHOD_REQUIRED' using errcode = 'P0001';
    end if;
    v_txn_id := public._service_insert_transaction(
      p_store_id, v_branch, v_booking_id, null,
      trim(p_client_name), nullif(trim(p_client_phone), ''),
      v_total, v_deposit, p_payment_method,
      case when v_deposit >= v_total then 'full'::public.payment_kind
           else 'deposit'::public.payment_kind end,
      v_uid
    );
  end if;

  return jsonb_build_object(
    'booking_id', v_booking_id,
    'transaction_id', v_txn_id,
    'deposit', v_deposit,
    'balance_due', greatest(v_total - v_deposit, 0),
    'total', v_total
  );
end;
$$;

grant execute on function public.create_catalog_service_booking(
  uuid, text, text, timestamptz, jsonb, numeric, public.payment_method, text
) to authenticated;

-- ---------------------------------------------------------------------------
-- Collect remainder (or full) on the same transaction when a deposit exists
-- ---------------------------------------------------------------------------
create or replace function public.collect_service_payment(
  p_booking_id uuid,
  p_amount numeric,
  p_payment_method public.payment_method
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_b public.service_bookings;
  v_uid uuid := auth.uid();
  v_txn_id uuid;
  v_total numeric;
  v_paid numeric;
  v_due numeric;
  v_add numeric := coalesce(p_amount, 0);
  v_state public.payment_state;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED' using errcode = 'P0001';
  end if;
  select * into v_b from public.service_bookings where id = p_booking_id for update;
  if v_b.id is null then
    raise exception 'BOOKING_NOT_FOUND' using errcode = 'P0001';
  end if;
  if not public.is_store_member(v_b.store_id) then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
  if v_add <= 0 then
    raise exception 'PAYMENT_AMOUNT_INVALID' using errcode = 'P0001';
  end if;

  select coalesce(sum(quantity * unit_price), 0)
  into v_total
  from public.service_booking_items
  where booking_id = v_b.id;

  v_txn_id := v_b.transaction_id;
  if v_txn_id is null then
    v_txn_id := public._service_insert_transaction(
      v_b.store_id, v_b.branch_id, v_b.id, v_b.quote_id,
      v_b.client_name, v_b.client_phone, v_total, v_add,
      p_payment_method,
      case when v_add >= v_total then 'full'::public.payment_kind
           else 'deposit'::public.payment_kind end,
      v_uid
    );
  else
    select amount_paid, balance_due into v_paid, v_due
    from public.transactions where id = v_txn_id for update;
    if v_add > coalesce(v_due, v_total) then
      v_add := coalesce(v_due, v_total);
    end if;
    if v_add <= 0 then
      raise exception 'BALANCE_ALREADY_PAID' using errcode = 'P0001';
    end if;
    v_paid := coalesce(v_paid, 0) + v_add;
    v_due := greatest(v_total - v_paid, 0);
    v_state := case
      when v_due <= 0 then 'paid'::public.payment_state
      else 'deposit_paid'::public.payment_state
    end;
    update public.transactions
    set
      amount_paid = v_paid,
      balance_due = v_due,
      payment_state = v_state,
      payment_method = p_payment_method
    where id = v_txn_id;
    insert into public.transaction_payments (
      transaction_id, amount, payment_method, kind, created_by
    ) values (
      v_txn_id, v_add, p_payment_method, 'balance', v_uid
    );
  end if;

  return jsonb_build_object(
    'booking_id', v_b.id,
    'transaction_id', v_txn_id,
    'amount', v_add
  );
end;
$$;

grant execute on function public.collect_service_payment(
  uuid, numeric, public.payment_method
) to authenticated;

create or replace function public.set_service_booking_status(
  p_booking_id uuid,
  p_status public.service_booking_status
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store uuid;
begin
  select store_id into v_store from public.service_bookings where id = p_booking_id;
  if v_store is null then
    raise exception 'BOOKING_NOT_FOUND' using errcode = 'P0001';
  end if;
  if not public.is_store_member(v_store) then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
  -- Cancel does not flip quote status or auto-refund.
  update public.service_bookings
  set status = p_status, updated_at = now()
  where id = p_booking_id;
end;
$$;

grant execute on function public.set_service_booking_status(
  uuid, public.service_booking_status
) to authenticated;

create or replace function public.report_service_stats(
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
  v_sent int;
  v_accepted int;
  v_avg numeric;
  v_outstanding int;
  v_upcoming int;
  v_completed int;
  v_deposit_out numeric;
  v_by_service jsonb;
begin
  if not public.is_store_member(p_store_id) then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  select
    count(*) filter (where status in ('sent', 'accepted', 'rejected'))::int,
    count(*) filter (where status = 'accepted')::int,
    avg(estimated_total) filter (where status in ('sent', 'accepted')),
    count(*) filter (
      where status = 'sent'
        and (valid_until is null or valid_until >= current_date)
    )::int
  into v_sent, v_accepted, v_avg, v_outstanding
  from public.quotes
  where store_id = p_store_id
    and created_at >= p_start
    and created_at < p_end
    and (p_branch_id is null or branch_id = p_branch_id);

  select
    count(*) filter (where status = 'upcoming')::int,
    count(*) filter (where status = 'completed')::int
  into v_upcoming, v_completed
  from public.service_bookings
  where store_id = p_store_id
    and (p_branch_id is null or branch_id = p_branch_id);

  select coalesce(sum(t.balance_due), 0)
  into v_deposit_out
  from public.transactions t
  where t.store_id = p_store_id
    and t.business_type = 'service'
    and t.payment_state in ('deposit_paid', 'unpaid')
    and t.balance_due > 0
    and (p_branch_id is null or t.branch_id = p_branch_id);

  select coalesce(jsonb_agg(x), '[]'::jsonb)
  into v_by_service
  from (
    select
      ti.name_snapshot as item_name,
      sum(ti.quantity) as units_sold,
      sum(ti.line_total) as revenue
    from public.transaction_items ti
    join public.transactions t on t.id = ti.transaction_id
    where t.store_id = p_store_id
      and t.business_type = 'service'
      and t.payment_state in ('paid', 'deposit_paid')
      and t.paid_at >= p_start
      and t.paid_at < p_end
      and (p_branch_id is null or t.branch_id = p_branch_id)
    group by ti.name_snapshot
    order by sum(ti.line_total) desc
    limit 20
  ) x;

  return jsonb_build_object(
    'quotes_sent', coalesce(v_sent, 0),
    'quotes_accepted', coalesce(v_accepted, 0),
    'conversion_rate', case when coalesce(v_sent, 0) = 0 then 0
      else round((coalesce(v_accepted, 0)::numeric / v_sent) * 100, 1) end,
    'average_quote_value', coalesce(v_avg, 0),
    'outstanding_quotes', coalesce(v_outstanding, 0),
    'upcoming_bookings', coalesce(v_upcoming, 0),
    'completed_bookings', coalesce(v_completed, 0),
    'outstanding_deposits', coalesce(v_deposit_out, 0),
    'revenue_by_service', coalesce(v_by_service, '[]'::jsonb)
  );
end;
$$;

grant execute on function public.report_service_stats(
  uuid, timestamptz, timestamptz, uuid
) to authenticated;

-- ---------------------------------------------------------------------------
-- RLS
-- ---------------------------------------------------------------------------
alter table public.services enable row level security;
alter table public.service_addons enable row level security;
alter table public.quotes enable row level security;
alter table public.quote_line_items enable row level security;
alter table public.service_bookings enable row level security;
alter table public.service_booking_items enable row level security;
alter table public.transaction_payments enable row level security;

drop policy if exists services_select_member on public.services;
drop policy if exists services_insert_member on public.services;
drop policy if exists services_update_member on public.services;
drop policy if exists services_delete_member on public.services;
create policy services_select_member on public.services
  for select using (public.is_store_member(store_id));
create policy services_insert_member on public.services
  for insert with check (public.is_store_member(store_id));
create policy services_update_member on public.services
  for update using (public.is_store_member(store_id))
  with check (public.is_store_member(store_id));
create policy services_delete_member on public.services
  for delete using (public.is_store_member(store_id));

drop policy if exists service_addons_all on public.service_addons;
create policy service_addons_all on public.service_addons
  for all using (
    exists (
      select 1 from public.services s
      where s.id = service_id and public.is_store_member(s.store_id)
    )
  )
  with check (
    exists (
      select 1 from public.services s
      where s.id = service_id and public.is_store_member(s.store_id)
    )
  );

drop policy if exists quotes_select_member on public.quotes;
drop policy if exists quotes_insert_member on public.quotes;
drop policy if exists quotes_update_member on public.quotes;
drop policy if exists quotes_delete_member on public.quotes;
create policy quotes_select_member on public.quotes
  for select using (public.is_store_member(store_id));
create policy quotes_insert_member on public.quotes
  for insert with check (public.is_store_member(store_id) and created_by = auth.uid());
create policy quotes_update_member on public.quotes
  for update using (public.is_store_member(store_id));
create policy quotes_delete_member on public.quotes
  for delete using (public.is_store_member(store_id));

drop policy if exists quote_lines_all on public.quote_line_items;
create policy quote_lines_all on public.quote_line_items
  for all using (
    exists (
      select 1 from public.quotes q
      where q.id = quote_id and public.is_store_member(q.store_id)
    )
  )
  with check (
    exists (
      select 1 from public.quotes q
      where q.id = quote_id and public.is_store_member(q.store_id)
    )
  );

drop policy if exists service_bookings_select on public.service_bookings;
drop policy if exists service_bookings_insert on public.service_bookings;
drop policy if exists service_bookings_update on public.service_bookings;
drop policy if exists service_bookings_delete on public.service_bookings;
create policy service_bookings_select on public.service_bookings
  for select using (public.is_store_member(store_id));
create policy service_bookings_insert on public.service_bookings
  for insert with check (public.is_store_member(store_id));
create policy service_bookings_update on public.service_bookings
  for update using (public.is_store_member(store_id));
create policy service_bookings_delete on public.service_bookings
  for delete using (public.is_store_member(store_id));

drop policy if exists service_booking_items_all on public.service_booking_items;
create policy service_booking_items_all on public.service_booking_items
  for all using (
    exists (
      select 1 from public.service_bookings b
      where b.id = booking_id and public.is_store_member(b.store_id)
    )
  )
  with check (
    exists (
      select 1 from public.service_bookings b
      where b.id = booking_id and public.is_store_member(b.store_id)
    )
  );

drop policy if exists transaction_payments_select on public.transaction_payments;
drop policy if exists transaction_payments_insert on public.transaction_payments;
create policy transaction_payments_select on public.transaction_payments
  for select using (
    exists (
      select 1 from public.transactions t
      where t.id = transaction_id and public.is_store_member(t.store_id)
    )
  );
create policy transaction_payments_insert on public.transaction_payments
  for insert with check (
    exists (
      select 1 from public.transactions t
      where t.id = transaction_id and public.is_store_member(t.store_id)
    )
  );

revoke all on function public._service_insert_transaction(
  uuid, uuid, uuid, uuid, text, text, numeric, numeric,
  public.payment_method, public.payment_kind, uuid
) from public, anon, authenticated;

grant select, insert, update, delete on public.services to authenticated;
grant select, insert, update, delete on public.service_addons to authenticated;
grant select, insert, update, delete on public.quotes to authenticated;
grant select, insert, update, delete on public.quote_line_items to authenticated;
grant select, insert, update, delete on public.service_bookings to authenticated;
grant select, insert, update, delete on public.service_booking_items to authenticated;
grant select, insert on public.transaction_payments to authenticated;

notify pgrst, 'reload schema';
