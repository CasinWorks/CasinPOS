-- Team manage: list members + pending invites, change role, remove, revoke invite.

create or replace function public.list_store_team(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_members jsonb;
  v_invites jsonb;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if not public.has_store_role(
    p_store_id,
    array['owner', 'admin']::public.store_role[]
  ) then
    raise exception 'FORBIDDEN';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', m.id,
      'user_id', m.user_id,
      'role', m.role,
      'status', m.status,
      'created_at', m.created_at,
      'full_name', p.full_name,
      'email', u.email,
      'is_self', m.user_id = auth.uid()
    )
    order by
      case m.role
        when 'owner' then 0
        when 'admin' then 1
        when 'manager' then 2
        else 3
      end,
      m.created_at
  ), '[]'::jsonb)
  into v_members
  from public.store_members m
  join public.profiles p on p.id = m.user_id
  left join auth.users u on u.id = m.user_id
  where m.store_id = p_store_id
    and m.status = 'active';

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', i.id,
      'email', i.email,
      'role', i.role,
      'status', i.status,
      'token', i.token,
      'expires_at', i.expires_at,
      'created_at', i.created_at
    )
    order by i.created_at desc
  ), '[]'::jsonb)
  into v_invites
  from public.store_invitations i
  where i.store_id = p_store_id
    and i.status = 'pending'
    and i.expires_at > now();

  return jsonb_build_object(
    'members', v_members,
    'invitations', v_invites
  );
end;
$$;

grant execute on function public.list_store_team(uuid) to authenticated;

create or replace function public.update_store_member_role(
  p_member_id uuid,
  p_role public.store_role
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target public.store_members%rowtype;
  v_actor_role public.store_role;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_target
  from public.store_members
  where id = p_member_id
    and status = 'active';

  if not found then
    raise exception 'MEMBER_NOT_FOUND';
  end if;

  if not public.has_store_role(
    v_target.store_id,
    array['owner', 'admin']::public.store_role[]
  ) then
    raise exception 'FORBIDDEN';
  end if;

  v_actor_role := public.member_role(v_target.store_id);

  if p_role = 'owner' then
    raise exception 'CANNOT_ASSIGN_OWNER';
  end if;

  if v_target.role = 'owner' then
    raise exception 'CANNOT_CHANGE_OWNER_ROLE';
  end if;

  if v_target.user_id = auth.uid() then
    raise exception 'CANNOT_CHANGE_OWN_ROLE';
  end if;

  if v_actor_role = 'admin' then
    if v_target.role = 'admin' then
      raise exception 'ADMIN_CANNOT_MANAGE_ADMIN';
    end if;
    if p_role = 'admin' then
      raise exception 'ADMIN_CANNOT_INVITE_ADMIN';
    end if;
  end if;

  update public.store_members
  set role = p_role
  where id = p_member_id;
end;
$$;

grant execute on function public.update_store_member_role(uuid, public.store_role) to authenticated;

create or replace function public.remove_store_member(p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target public.store_members%rowtype;
  v_actor_role public.store_role;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_target
  from public.store_members
  where id = p_member_id
    and status = 'active';

  if not found then
    raise exception 'MEMBER_NOT_FOUND';
  end if;

  if not public.has_store_role(
    v_target.store_id,
    array['owner', 'admin']::public.store_role[]
  ) then
    raise exception 'FORBIDDEN';
  end if;

  v_actor_role := public.member_role(v_target.store_id);

  if v_target.role = 'owner' then
    raise exception 'CANNOT_REMOVE_OWNER';
  end if;

  if v_target.user_id = auth.uid() then
    raise exception 'CANNOT_REMOVE_SELF';
  end if;

  if v_actor_role = 'admin' and v_target.role = 'admin' then
    raise exception 'ADMIN_CANNOT_MANAGE_ADMIN';
  end if;

  update public.store_members
  set status = 'disabled'
  where id = p_member_id;
end;
$$;

grant execute on function public.remove_store_member(uuid) to authenticated;

create or replace function public.revoke_store_invitation(p_invitation_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inv public.store_invitations%rowtype;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_inv
  from public.store_invitations
  where id = p_invitation_id;

  if not found then
    raise exception 'INVITE_NOT_FOUND';
  end if;

  if not public.has_store_role(
    v_inv.store_id,
    array['owner', 'admin']::public.store_role[]
  ) then
    raise exception 'FORBIDDEN';
  end if;

  if v_inv.status <> 'pending' then
    raise exception 'INVITE_NOT_PENDING';
  end if;

  update public.store_invitations
  set status = 'revoked'
  where id = p_invitation_id;
end;
$$;

grant execute on function public.revoke_store_invitation(uuid) to authenticated;
