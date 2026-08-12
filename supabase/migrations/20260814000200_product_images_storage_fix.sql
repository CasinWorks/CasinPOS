-- Product images bucket + storage RLS (align with member inventory writes).
-- Fixes: StorageException 403 "new row violates row-level security policy" on photo upload.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'product-images',
  'product-images',
  true,
  5242880, -- 5 MB
  array['image/jpeg', 'image/png', 'image/webp', 'image/gif']
)
on conflict (id) do update set
  public = excluded.public,
  file_size_limit = excluded.file_size_limit,
  allowed_mime_types = excluded.allowed_mime_types;

create or replace function public.storage_store_id(object_name text)
returns uuid
language plpgsql
immutable
as $$
begin
  return nullif(split_part(object_name, '/', 1), '')::uuid;
exception
  when others then
    return null;
end;
$$;

drop policy if exists product_images_select on storage.objects;
create policy product_images_select on storage.objects
  for select
  using (bucket_id = 'product-images');

drop policy if exists product_images_insert on storage.objects;
create policy product_images_insert on storage.objects
  for insert
  with check (
    bucket_id = 'product-images'
    and public.is_store_member(public.storage_store_id(name))
  );

drop policy if exists product_images_update on storage.objects;
create policy product_images_update on storage.objects
  for update
  using (
    bucket_id = 'product-images'
    and public.is_store_member(public.storage_store_id(name))
  )
  with check (
    bucket_id = 'product-images'
    and public.is_store_member(public.storage_store_id(name))
  );

drop policy if exists product_images_delete on storage.objects;
create policy product_images_delete on storage.objects
  for delete
  using (
    bucket_id = 'product-images'
    and public.is_store_member(public.storage_store_id(name))
  );
