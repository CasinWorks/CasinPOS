-- Service enums + store/transaction columns.
-- 'service' is added to business_type here but not used until the next
-- migration (Postgres cannot use a newly added enum value in the same txn).

alter type public.business_type add value if not exists 'service';

do $$
begin
  create type public.service_pricing_mode as enum ('fixed', 'quote');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.quote_status as enum ('draft', 'sent', 'accepted', 'rejected');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.service_booking_status as enum ('upcoming', 'completed', 'cancelled');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.payment_state as enum ('unpaid', 'deposit_paid', 'paid');
exception
  when duplicate_object then null;
end $$;

do $$
begin
  create type public.payment_kind as enum ('deposit', 'balance', 'full');
exception
  when duplicate_object then null;
end $$;

alter table public.stores
  add column if not exists service_pricing_mode public.service_pricing_mode;

alter table public.transactions
  add column if not exists client_phone text,
  add column if not exists amount_paid numeric(12, 2) not null default 0,
  add column if not exists balance_due numeric(12, 2) not null default 0,
  add column if not exists payment_state public.payment_state not null default 'unpaid',
  add column if not exists service_booking_id uuid,
  add column if not exists quote_id uuid;

update public.transactions
set
  payment_state = 'paid',
  amount_paid = coalesce(total, 0),
  balance_due = 0
where status = 'paid'
  and payment_state = 'unpaid'
  and amount_paid = 0;
