-- Optional digital / card payments (Cash is always accepted).
alter table public.stores
  add column if not exists accept_gcash boolean not null default true,
  add column if not exists accept_maya boolean not null default true,
  add column if not exists accept_card boolean not null default true;

comment on column public.stores.accept_gcash is 'When true, GCash appears at checkout. Cash is always available.';
comment on column public.stores.accept_maya is 'When true, Maya appears at checkout. Cash is always available.';
comment on column public.stores.accept_card is 'When true, Card appears at checkout. Cash is always available.';
