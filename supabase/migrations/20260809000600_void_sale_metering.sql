-- When a paid sale is voided, return one slot to the free-tier monthly counter.
create or replace function public.on_transaction_voided()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if old.status = 'paid'
     and new.status = 'voided' then
    update public.stores
    set
      transactions_this_period = greatest(0, transactions_this_period - 1),
      updated_at = now()
    where id = new.store_id;
  end if;
  return new;
end;
$$;

drop trigger if exists transactions_voided_metering on public.transactions;
create trigger transactions_voided_metering
  after update of status on public.transactions
  for each row
  execute function public.on_transaction_voided();
