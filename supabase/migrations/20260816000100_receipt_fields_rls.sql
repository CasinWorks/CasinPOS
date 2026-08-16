-- Ensure receipt legal fields exist and store updates are allowed for owner/admin.
-- Safe to re-run if Script B was already applied.

alter table public.stores
  add column if not exists business_tin text,
  add column if not exists business_address text;

comment on column public.stores.business_tin is 'BIR TIN shown on receipts';
comment on column public.stores.business_address is 'Business address shown on receipts';

-- Explicit WITH CHECK so UPDATE … RETURNING works reliably under RLS.
drop policy if exists stores_update_owner_admin on public.stores;
create policy stores_update_owner_admin on public.stores
  for update
  using (
    public.has_store_role(id, array['owner', 'admin']::public.store_role[])
  )
  with check (
    public.has_store_role(id, array['owner', 'admin']::public.store_role[])
  );
