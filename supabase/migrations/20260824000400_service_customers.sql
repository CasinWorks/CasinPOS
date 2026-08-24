-- Saved clients for Service stores (returning customers).

create table if not exists public.service_customers (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  name text not null,
  phone text,
  email text,
  notes text,
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index if not exists service_customers_store_name_idx
  on public.service_customers (store_id, lower(btrim(name)));

create unique index if not exists service_customers_store_phone_uidx
  on public.service_customers (store_id, btrim(phone))
  where phone is not null and btrim(phone) <> '';

create unique index if not exists service_customers_store_name_nophone_uidx
  on public.service_customers (store_id, lower(btrim(name)))
  where phone is null or btrim(phone) = '';

alter table public.service_customers enable row level security;

drop policy if exists service_customers_select on public.service_customers;
drop policy if exists service_customers_insert on public.service_customers;
drop policy if exists service_customers_update on public.service_customers;
drop policy if exists service_customers_delete on public.service_customers;

create policy service_customers_select on public.service_customers
  for select using (public.is_store_member(store_id));
create policy service_customers_insert on public.service_customers
  for insert with check (public.is_store_member(store_id));
create policy service_customers_update on public.service_customers
  for update using (public.is_store_member(store_id))
  with check (public.is_store_member(store_id));
create policy service_customers_delete on public.service_customers
  for delete using (public.is_store_member(store_id));

grant select, insert, update, delete on public.service_customers to authenticated;

create or replace function public.upsert_service_customer(
  p_store_id uuid,
  p_name text,
  p_phone text default null,
  p_email text default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_name text := btrim(coalesce(p_name, ''));
  v_phone text := nullif(btrim(coalesce(p_phone, '')), '');
  v_email text := nullif(btrim(coalesce(p_email, '')), '');
  v_id uuid;
begin
  if not public.is_store_member(p_store_id) then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;
  if length(v_name) < 1 then
    raise exception 'CLIENT_NAME_REQUIRED' using errcode = 'P0001';
  end if;

  if v_phone is not null then
    select id into v_id
    from public.service_customers
    where store_id = p_store_id and btrim(phone) = v_phone
    limit 1;
  end if;

  if v_id is null then
    select id into v_id
    from public.service_customers
    where store_id = p_store_id
      and lower(btrim(name)) = lower(v_name)
      and (v_phone is null or phone is null or btrim(phone) = '')
    limit 1;
  end if;

  if v_id is null then
    insert into public.service_customers (store_id, name, phone, email, last_seen_at)
    values (p_store_id, v_name, v_phone, v_email, now())
    returning id into v_id;
  else
    update public.service_customers
    set
      name = v_name,
      phone = coalesce(v_phone, phone),
      email = coalesce(v_email, email),
      last_seen_at = now(),
      updated_at = now()
    where id = v_id;
  end if;

  return jsonb_build_object('id', v_id, 'name', v_name, 'phone', v_phone, 'email', v_email);
end;
$$;

grant execute on function public.upsert_service_customer(uuid, text, text, text) to authenticated;

-- Backfill from quotes and bookings.
insert into public.service_customers (store_id, name, phone, email, last_seen_at)
select distinct on (q.store_id, lower(btrim(q.client_name)), coalesce(btrim(q.client_phone), ''))
  q.store_id,
  btrim(q.client_name),
  nullif(btrim(q.client_phone), ''),
  nullif(btrim(q.client_email), ''),
  q.created_at
from public.quotes q
where length(btrim(q.client_name)) > 0
order by q.store_id, lower(btrim(q.client_name)), coalesce(btrim(q.client_phone), ''), q.created_at desc
on conflict do nothing;

insert into public.service_customers (store_id, name, phone, last_seen_at)
select distinct on (b.store_id, lower(btrim(b.client_name)), coalesce(btrim(b.client_phone), ''))
  b.store_id,
  btrim(b.client_name),
  nullif(btrim(b.client_phone), ''),
  b.created_at
from public.service_bookings b
where length(btrim(b.client_name)) > 0
  and not exists (
    select 1 from public.service_customers c
    where c.store_id = b.store_id
      and lower(btrim(c.name)) = lower(btrim(b.client_name))
      and coalesce(btrim(c.phone), '') = coalesce(btrim(b.client_phone), '')
  )
order by b.store_id, lower(btrim(b.client_name)), coalesce(btrim(b.client_phone), ''), b.created_at desc
on conflict do nothing;

notify pgrst, 'reload schema';
