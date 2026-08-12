-- Product timed sales + store discount codes + transaction discount audit.

-- ── products: sale window ───────────────────────────────────────────────────
alter table public.products
  add column if not exists sale_price numeric check (sale_price is null or sale_price >= 0),
  add column if not exists sale_starts_at timestamptz,
  add column if not exists sale_ends_at timestamptz;

-- ── transactions: cart-level code discount ──────────────────────────────────
alter table public.transactions
  add column if not exists discount_code text,
  add column if not exists discount_amount numeric not null default 0
    check (discount_amount >= 0);

-- ── discount_codes ──────────────────────────────────────────────────────────
create table if not exists public.discount_codes (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores(id) on delete cascade,
  code text not null,
  kind text not null check (kind in ('percent', 'fixed')),
  value numeric not null check (value > 0),
  is_active boolean not null default true,
  starts_at timestamptz,
  ends_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint discount_codes_code_nonempty check (length(trim(code)) >= 2),
  constraint discount_codes_percent_range check (
    kind <> 'percent' or (value > 0 and value <= 100)
  ),
  constraint discount_codes_store_code_unique unique (store_id, code)
);

create index if not exists discount_codes_store_idx
  on public.discount_codes (store_id);

alter table public.discount_codes enable row level security;

drop policy if exists discount_codes_select_member on public.discount_codes;
drop policy if exists discount_codes_insert_admin on public.discount_codes;
drop policy if exists discount_codes_update_admin on public.discount_codes;
drop policy if exists discount_codes_delete_admin on public.discount_codes;

create policy discount_codes_select_member on public.discount_codes
  for select
  using (public.is_store_member(store_id));

create policy discount_codes_insert_admin on public.discount_codes
  for insert
  with check (
    public.has_store_role(store_id, array['owner', 'admin']::public.store_role[])
  );

create policy discount_codes_update_admin on public.discount_codes
  for update
  using (
    public.has_store_role(store_id, array['owner', 'admin']::public.store_role[])
  )
  with check (
    public.has_store_role(store_id, array['owner', 'admin']::public.store_role[])
  );

create policy discount_codes_delete_admin on public.discount_codes
  for delete
  using (
    public.has_store_role(store_id, array['owner', 'admin']::public.store_role[])
  );

grant select, insert, update, delete on public.discount_codes to authenticated;
