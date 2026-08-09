-- Permanently delete a franchise (child) store.
-- Caller must be Owner/Admin of the franchisor (parent). Related rows cascade
-- via FKs (members, invites, branches, products, sales, register sessions, etc.).
-- The franchisor store is never deleted.

create or replace function public.delete_franchise_store(p_franchise_store_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_child public.stores%rowtype;
  v_name text;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_child
  from public.stores
  where id = p_franchise_store_id
  for update;

  if not found then
    raise exception 'STORE_NOT_FOUND';
  end if;

  -- Must be a franchise child linked to a parent.
  if v_child.franchisor_store_id is null then
    raise exception 'NOT_A_FRANCHISE';
  end if;

  if not public.has_store_role(
    v_child.franchisor_store_id,
    array['owner', 'admin']::public.store_role[]
  ) then
    raise exception 'FORBIDDEN';
  end if;

  v_name := v_child.name;

  -- Hard delete; child rows cascade. Parent franchisor_store_id FKs use SET NULL
  -- on parent delete — deleting the child does not touch the parent.
  delete from public.stores where id = p_franchise_store_id;

  return jsonb_build_object(
    'id', p_franchise_store_id,
    'name', v_name
  );
end;
$$;

grant execute on function public.delete_franchise_store(uuid) to authenticated;

comment on function public.delete_franchise_store(uuid) is
  'Owner/Admin of franchisor may permanently delete a linked franchise store and cascaded data.';
