-- Optional retail customer / shipping details on paid sales.
-- Used when payment is taken now and goods ship later (e.g. LBC).

alter table public.transactions
  add column if not exists customer_address text;

comment on column public.transactions.customer_name is
  'Optional buyer name for walk-in / ship-later retail sales.';
comment on column public.transactions.client_phone is
  'Optional buyer mobile (CP) number.';
comment on column public.transactions.customer_address is
  'Optional shipping address (e.g. LBC).';
