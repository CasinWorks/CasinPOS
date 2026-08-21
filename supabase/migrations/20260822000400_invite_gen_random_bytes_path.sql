-- pgcrypto lives in extensions on hosted Supabase. search_path = public
-- made gen_random_bytes() fail (42883) on every invite UPDATE.

create or replace function public.create_store_invitation(
  p_store_id uuid,
  p_email text,
  p_role text,
  p_branch_ids jsonb default null
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_email text := lower(trim(p_email));
  v_role public.store_role;
  v_row public.store_invitations;
  v_actor public.store_role;
  v_valid_branches uuid[];
  v_resent boolean := false;
  v_token text := encode(extensions.gen_random_bytes(24), 'hex');
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED' using errcode = 'P0001';
  end if;

  if not public.has_store_role(p_store_id, array['owner', 'admin']::public.store_role[]) then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  select public.member_role(p_store_id) into v_actor;

  begin
    v_role := lower(trim(p_role))::public.store_role;
  exception
    when invalid_text_representation then
      raise exception 'FORBIDDEN' using errcode = 'P0001';
  end;

  if v_role = 'owner' then
    raise exception 'CANNOT_INVITE_OWNER' using errcode = 'P0001';
  end if;

  if v_role = 'admin' and v_actor is distinct from 'owner' then
    raise exception 'ADMIN_CANNOT_INVITE_ADMIN' using errcode = 'P0001';
  end if;

  if v_role not in ('admin', 'manager', 'branch_manager', 'staff') then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  if v_email is null or v_email !~ '^[^@]+@[^@]+\.[^@]+$' then
    raise exception 'EMAIL_INVALID' using errcode = 'P0001';
  end if;

  if exists (
    select 1
    from public.store_members m
    join auth.users u on u.id = m.user_id
    where m.store_id = p_store_id
      and m.status = 'active'
      and lower(u.email) = v_email
  ) then
    raise exception 'ALREADY_A_MEMBER' using errcode = 'P0001';
  end if;

  if p_branch_ids is not null and jsonb_typeof(p_branch_ids) = 'array' then
    select array_agg(elem::uuid)
    into v_valid_branches
    from jsonb_array_elements_text(p_branch_ids) as t(elem)
    where elem is not null and elem <> '';
  end if;

  if v_role = 'branch_manager' then
    if v_valid_branches is null or cardinality(v_valid_branches) = 0 then
      raise exception 'BRANCH_IDS_REQUIRED' using errcode = 'P0001';
    end if;
    select array_agg(b.id)
    into v_valid_branches
    from public.branches b
    where b.store_id = p_store_id
      and b.id = any (v_valid_branches);
    if v_valid_branches is null or cardinality(v_valid_branches) = 0 then
      raise exception 'BRANCH_IDS_INVALID' using errcode = 'P0001';
    end if;
  end if;

  perform public.assert_free_team_seat_available(
    p_store_id,
    v_email,
    true,
    'invite'
  );

  update public.store_invitations
  set
    role = v_role,
    branch_ids = v_valid_branches,
    invited_by = auth.uid(),
    token = v_token,
    expires_at = now() + interval '14 days',
    status = 'pending'
  where store_id = p_store_id
    and email = v_email
    and status = 'pending'
  returning * into v_row;

  if v_row.id is null then
    insert into public.store_invitations (
      store_id, email, role, branch_ids, invited_by, token
    ) values (
      p_store_id, v_email, v_role, v_valid_branches, auth.uid(), v_token
    )
    returning * into v_row;
  else
    v_resent := true;
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'store_id', v_row.store_id,
    'email', v_row.email,
    'role', v_row.role,
    'branch_ids', to_jsonb(v_row.branch_ids),
    'token', v_row.token,
    'expires_at', v_row.expires_at,
    'status', v_row.status,
    'resent', v_resent
  );
end;
$$;

grant execute on function public.create_store_invitation(uuid, text, text, jsonb) to authenticated;
grant execute on function public.create_store_invitation(uuid, text, text, jsonb) to anon;

notify pgrst, 'reload schema';
