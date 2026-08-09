-- Lock store business_type after create; one-time fix for mistyped stores.

-- Fix known mistaken restaurant selection back to retail (Carmen’s, and any
-- free-tier owner store still on restaurant while restaurant POS is unfinished).
update public.stores
set
  business_type = 'retail',
  updated_at = now()
where business_type = 'restaurant'
  and lower(name) like '%carmen%';

create or replace function public.prevent_store_business_type_change()
returns trigger
language plpgsql
as $$
begin
  if tg_op = 'UPDATE'
     and new.business_type is distinct from old.business_type then
    raise exception
      'Business type is set when the store is created and cannot be changed';
  end if;
  return new;
end;
$$;

drop trigger if exists stores_lock_business_type on public.stores;
create trigger stores_lock_business_type
  before update on public.stores
  for each row
  execute function public.prevent_store_business_type_change();
