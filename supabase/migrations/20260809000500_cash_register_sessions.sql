-- Cash register sessions (till open/close) and pay-in / pay-out movements.

create table if not exists public.cash_sessions (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  branch_id uuid not null references public.branches (id) on delete cascade,
  opened_by uuid not null references public.profiles (id),
  closed_by uuid references public.profiles (id),
  opening_float numeric(12, 2) not null check (opening_float >= 0),
  closing_count numeric(12, 2) check (closing_count is null or closing_count >= 0),
  expected_cash numeric(12, 2),
  variance numeric(12, 2),
  notes text,
  opened_at timestamptz not null default now(),
  closed_at timestamptz,
  status text not null default 'open' check (status in ('open', 'closed')),
  created_at timestamptz not null default now()
);

create unique index if not exists cash_sessions_one_open_per_store
  on public.cash_sessions (store_id)
  where status = 'open';

create index if not exists cash_sessions_store_opened_idx
  on public.cash_sessions (store_id, opened_at desc);

create table if not exists public.cash_movements (
  id uuid primary key default gen_random_uuid(),
  session_id uuid not null references public.cash_sessions (id) on delete cascade,
  kind text not null check (kind in ('pay_in', 'pay_out')),
  amount numeric(12, 2) not null check (amount > 0),
  note text,
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

create index if not exists cash_movements_session_idx
  on public.cash_movements (session_id, created_at);

alter table public.cash_sessions enable row level security;
alter table public.cash_movements enable row level security;

drop policy if exists cash_sessions_select on public.cash_sessions;
create policy cash_sessions_select on public.cash_sessions
  for select using (public.is_store_member(store_id));

drop policy if exists cash_sessions_insert on public.cash_sessions;
create policy cash_sessions_insert on public.cash_sessions
  for insert with check (
    public.is_store_member(store_id) and opened_by = auth.uid()
  );

drop policy if exists cash_sessions_update on public.cash_sessions;
create policy cash_sessions_update on public.cash_sessions
  for update using (
    public.has_store_role(
      store_id,
      array['owner', 'admin', 'manager', 'staff']::public.store_role[]
    )
  );

drop policy if exists cash_movements_select on public.cash_movements;
create policy cash_movements_select on public.cash_movements
  for select using (
    exists (
      select 1 from public.cash_sessions s
      where s.id = session_id and public.is_store_member(s.store_id)
    )
  );

drop policy if exists cash_movements_insert on public.cash_movements;
create policy cash_movements_insert on public.cash_movements
  for insert with check (
    created_by = auth.uid()
    and exists (
      select 1 from public.cash_sessions s
      where s.id = session_id
        and s.status = 'open'
        and public.is_store_member(s.store_id)
    )
  );

grant select, insert, update on public.cash_sessions to authenticated;
grant select, insert on public.cash_movements to authenticated;
