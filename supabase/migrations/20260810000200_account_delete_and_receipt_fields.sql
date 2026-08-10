-- Store legal receipt fields + cashier claim on open register sessions.
alter table public.stores
  add column if not exists business_tin text,
  add column if not exists business_address text;

alter table public.cash_sessions
  add column if not exists claimed_by uuid references public.profiles (id),
  add column if not exists claimed_at timestamptz;

-- Soft account deletion for App Store compliance (PII cleared; memberships closed).
-- Hard delete of auth.users is performed by the delete-account Edge Function.
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

  -- Close memberships (non-owners leave; owners keep row until Edge Function removes stores or you reassign)
  update public.store_members
  set status = 'removed', updated_at = now()
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
