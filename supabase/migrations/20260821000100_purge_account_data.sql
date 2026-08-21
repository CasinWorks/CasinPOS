-- Fix account deletion for App Store 5.1.1(v).
-- Root cause: request_account_deletion referenced store_members.updated_at (column
-- does not exist) → 400, then auth.admin.deleteUser failed on stores.owner_id FKs.

-- Soft cleanup used by authenticated clients / Edge Function (user JWT).
create or replace function public.request_account_deletion()
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_uid uuid := auth.uid();
  v_owned int;
begin
  if v_uid is null then
    raise exception 'Not signed in';
  end if;

  select count(*) into v_owned
  from public.store_members
  where user_id = v_uid
    and status = 'active'
    and role = 'owner';

  update public.store_members
  set status = 'removed'
  where user_id = v_uid
    and status = 'active'
    and role <> 'owner';

  update public.profiles
  set
    full_name = 'Deleted User',
    avatar_url = null,
    phone = null,
    onboarding_completed = true,
    updated_at = now()
  where id = v_uid;

  return jsonb_build_object(
    'ok', true,
    'owned_stores', v_owned,
    'message', case
      when v_owned > 0 then
        'Account marked for deletion. Ownership of stores will be cleared by the delete-account function.'
      else
        'Account marked for deletion.'
    end
  );
end;
$$;

grant execute on function public.request_account_deletion() to authenticated;

-- Service-role purge: clears FK blockers, deletes sole-owned stores, then
-- auth.admin.deleteUser can succeed.
create or replace function public.purge_account_data(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store record;
  v_other_owner uuid;
  v_deleted_stores int := 0;
  v_reassigned_stores int := 0;
begin
  if p_user_id is null then
    raise exception 'USER_REQUIRED';
  end if;

  for v_store in
    select s.id
    from public.stores s
    where s.owner_id = p_user_id
  loop
    select sm.user_id into v_other_owner
    from public.store_members sm
    where sm.store_id = v_store.id
      and sm.status = 'active'
      and sm.role = 'owner'
      and sm.user_id <> p_user_id
    order by sm.created_at asc
    limit 1;

    if v_other_owner is null then
      delete from public.stores where id = v_store.id;
      v_deleted_stores := v_deleted_stores + 1;
    else
      update public.stores
      set owner_id = v_other_owner, updated_at = now()
      where id = v_store.id;
      v_reassigned_stores := v_reassigned_stores + 1;
    end if;
  end loop;

  update public.store_members
  set status = 'removed'
  where user_id = p_user_id
    and status = 'active';

  update public.store_members
  set invited_by = null
  where invited_by = p_user_id;

  update public.store_invitations
  set accepted_user_id = null
  where accepted_user_id = p_user_id;

  update public.store_invitations si
  set invited_by = s.owner_id
  from public.stores s
  where si.store_id = s.id
    and si.invited_by = p_user_id
    and s.owner_id <> p_user_id;

  delete from public.store_invitations
  where invited_by = p_user_id;

  update public.cash_sessions cs
  set opened_by = s.owner_id
  from public.stores s
  where cs.store_id = s.id
    and cs.opened_by = p_user_id
    and s.owner_id <> p_user_id;

  update public.cash_sessions
  set closed_by = null
  where closed_by = p_user_id;

  update public.cash_sessions
  set claimed_by = null
  where claimed_by = p_user_id;

  update public.cash_movements cm
  set created_by = s.owner_id
  from public.cash_sessions cs
  join public.stores s on s.id = cs.store_id
  where cm.session_id = cs.id
    and cm.created_by = p_user_id
    and s.owner_id <> p_user_id;

  update public.transactions t
  set staff_id = s.owner_id
  from public.stores s
  where t.store_id = s.id
    and t.staff_id = p_user_id
    and s.owner_id <> p_user_id;

  if to_regclass('public.platform_support_notes') is not null then
    delete from public.platform_support_notes where author_id = p_user_id;
  end if;
  if to_regclass('public.store_messages') is not null then
    delete from public.store_messages where created_by = p_user_id;
  end if;
  if to_regclass('public.platform_admin_audit') is not null then
    delete from public.platform_admin_audit where admin_id = p_user_id;
  end if;

  update public.profiles
  set
    full_name = 'Deleted User',
    avatar_url = null,
    phone = null,
    onboarding_completed = true,
    updated_at = now()
  where id = p_user_id;

  return jsonb_build_object(
    'ok', true,
    'deleted_stores', v_deleted_stores,
    'reassigned_stores', v_reassigned_stores
  );
end;
$$;

revoke all on function public.purge_account_data(uuid) from public;
grant execute on function public.purge_account_data(uuid) to service_role;
