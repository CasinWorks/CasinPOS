-- Live cart snapshots for native multi-device Customer Display (Realtime).

create table if not exists public.customer_display_snapshots (
  store_id uuid primary key references public.stores (id) on delete cascade,
  snapshot jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.profiles (id) on delete set null
);

comment on table public.customer_display_snapshots is
  'Latest POS cart payload for customer-facing display devices (same store).';

alter table public.customer_display_snapshots enable row level security;

drop policy if exists customer_display_select on public.customer_display_snapshots;
drop policy if exists customer_display_insert on public.customer_display_snapshots;
drop policy if exists customer_display_update on public.customer_display_snapshots;

-- Any store member can watch the display (second phone/tablet).
create policy customer_display_select on public.customer_display_snapshots
  for select using (public.is_store_member(store_id));

-- Any active store member can publish cart updates from the POS device.
create policy customer_display_insert on public.customer_display_snapshots
  for insert with check (public.is_store_member(store_id));

create policy customer_display_update on public.customer_display_snapshots
  for update
  using (public.is_store_member(store_id))
  with check (public.is_store_member(store_id));

grant select, insert, update on public.customer_display_snapshots to authenticated;

-- Enable Realtime fan-out to paired display devices.
do $$
begin
  alter publication supabase_realtime add table public.customer_display_snapshots;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
