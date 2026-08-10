-- Same refund columns as 20260810000100 — safe to re-run in SQL Editor.
alter table public.transaction_items
  add column if not exists refunded_quantity numeric(12, 3) not null default 0;

alter table public.transactions
  add column if not exists refunded_total numeric(12, 2) not null default 0;

create or replace function public.on_transaction_voided()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = 'paid'
     and new.status in ('voided', 'refunded') then
    update public.stores
    set
      transactions_this_period = greatest(0, transactions_this_period - 1),
      updated_at = now()
    where id = new.store_id;
  end if;
  return new;
end;
$$;
