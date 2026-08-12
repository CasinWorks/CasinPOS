-- Fix products/categories RLS so inventory saves work for active members.
-- Symptom: PostgrestException 42501 "new row violates row-level security policy for table products"
--
-- Cause: FOR ALL + USING-only write policies are brittle on INSERT/UPSERT WITH CHECK.
-- Retail launch: any active store member may manage catalog (POS day-to-day).

drop policy if exists products_write_managers on public.products;
drop policy if exists products_insert_member on public.products;
drop policy if exists products_update_member on public.products;
drop policy if exists products_delete_member on public.products;

create policy products_insert_member on public.products
  for insert
  with check (public.is_store_member(store_id));

create policy products_update_member on public.products
  for update
  using (public.is_store_member(store_id))
  with check (public.is_store_member(store_id));

create policy products_delete_member on public.products
  for delete
  using (public.is_store_member(store_id));

drop policy if exists categories_write_managers on public.categories;
drop policy if exists categories_insert_member on public.categories;
drop policy if exists categories_update_member on public.categories;
drop policy if exists categories_delete_member on public.categories;

create policy categories_insert_member on public.categories
  for insert
  with check (public.is_store_member(store_id));

create policy categories_update_member on public.categories
  for update
  using (public.is_store_member(store_id))
  with check (public.is_store_member(store_id));

create policy categories_delete_member on public.categories
  for delete
  using (public.is_store_member(store_id));
