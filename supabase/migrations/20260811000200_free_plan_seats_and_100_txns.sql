-- Free plan: 100 paid txns/month + max 2 active seats (owner + 1 teammate).

alter table public.stores
  alter column monthly_transaction_limit set default 100;

-- Existing free stores still on 50 → bump to 100 (ops can override per store).
update public.stores
set
  monthly_transaction_limit = 100,
  updated_at = now()
where plan_tier = 'free'
  and monthly_transaction_limit = 50;

create or replace function public.free_team_seat_limit()
returns int
language sql
immutable
as $$
  select 2;
$$;

-- Active members + distinct pending non-owner invites that aren't already members.
create or replace function public.store_seat_usage(p_store_id uuid)
returns table (
  active_members int,
  pending_invites int,
  seats_used int
)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_active int;
  v_pending int;
begin
  select count(*)::int into v_active
  from public.store_members
  where store_id = p_store_id
    and status = 'active';

  select count(*)::int into v_pending
  from public.store_invitations i
  where i.store_id = p_store_id
    and i.status = 'pending'
    and i.role <> 'owner'
    and i.expires_at > now()
    and not exists (
      select 1
      from public.store_members m
      join auth.users u on u.id = m.user_id
      where m.store_id = p_store_id
        and m.status = 'active'
        and lower(u.email) = lower(i.email)
    );

  active_members := coalesce(v_active, 0);
  pending_invites := coalesce(v_pending, 0);
  seats_used := active_members + pending_invites;
  return next;
end;
$$;

grant execute on function public.store_seat_usage(uuid) to authenticated;

create or replace function public.assert_free_team_seat_available(
  p_store_id uuid,
  p_email text default null,
  p_allow_if_pending_same_email boolean default false,
  p_mode text default 'invite'
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_tier public.plan_tier;
  v_usage record;
  v_email text := lower(trim(coalesce(p_email, '')));
  v_limit int := public.free_team_seat_limit();
begin
  select plan_tier into v_tier from public.stores where id = p_store_id;
  if v_tier is distinct from 'free' then
    return;
  end if;

  select * into v_usage from public.store_seat_usage(p_store_id);

  -- Already an active member → no new seat.
  if v_email <> '' and exists (
    select 1
    from public.store_members m
    join auth.users u on u.id = m.user_id
    where m.store_id = p_store_id
      and m.status = 'active'
      and lower(u.email) = v_email
  ) then
    return;
  end if;

  -- Accepting converts a reserved pending seat → only block if actives already full.
  if p_mode = 'accept' then
    if v_usage.active_members >= v_limit then
      raise exception 'FREE_TEAM_SEAT_LIMIT'
        using errcode = 'P0001',
              detail = format(
                'Free plan allows %s people on this store (owner + 1 teammate). Upgrade to Premium for more staff.',
                v_limit
              );
    end if;
    return;
  end if;

  -- Invite resend for the same pending email does not consume an extra seat.
  if p_allow_if_pending_same_email and v_email <> '' then
    if exists (
      select 1
      from public.store_invitations i
      where i.store_id = p_store_id
        and i.status = 'pending'
        and lower(i.email) = v_email
        and i.expires_at > now()
    ) then
      return;
    end if;
  end if;

  if v_usage.seats_used >= v_limit then
    raise exception 'FREE_TEAM_SEAT_LIMIT'
      using errcode = 'P0001',
            detail = format(
              'Free plan allows %s people on this store (owner + 1 teammate). Upgrade to Premium for more staff.',
              v_limit
            );
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- Invitations (preserve resend behavior; add seat gate for new invites)
-- -----------------------------------------------------------------------------
drop function if exists public.create_store_invitation(uuid, text, public.store_role, uuid[]);

create function public.create_store_invitation(
  p_store_id uuid,
  p_email text,
  p_role public.store_role,
  p_branch_ids uuid[] default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_email text := lower(trim(p_email));
  v_row public.store_invitations;
  v_resent boolean := false;
begin
  if not public.has_store_role(p_store_id, array['owner', 'admin']::public.store_role[]) then
    raise exception 'FORBIDDEN';
  end if;

  if p_role = 'owner' then
    raise exception 'CANNOT_INVITE_OWNER';
  end if;

  if public.member_role(p_store_id) = 'admin' and p_role = 'admin' then
    raise exception 'ADMIN_CANNOT_INVITE_ADMIN';
  end if;

  if v_email is null or position('@' in v_email) < 2 then
    raise exception 'EMAIL_INVALID';
  end if;

  -- Seat check before insert (resend of same email skips).
  perform public.assert_free_team_seat_available(
    p_store_id,
    v_email,
    true,
    'invite'
  );

  select * into v_row
  from public.store_invitations
  where store_id = p_store_id
    and email = v_email
    and status = 'pending'
  for update;

  if found then
    update public.store_invitations
    set
      role = p_role,
      branch_ids = p_branch_ids,
      invited_by = auth.uid(),
      expires_at = now() + interval '7 days'
    where id = v_row.id
    returning * into v_row;
    v_resent := true;
  else
    insert into public.store_invitations (
      store_id, email, role, branch_ids, invited_by
    ) values (
      p_store_id, v_email, p_role, p_branch_ids, auth.uid()
    )
    returning * into v_row;
  end if;

  return jsonb_build_object(
    'id', v_row.id,
    'store_id', v_row.store_id,
    'email', v_row.email,
    'role', v_row.role,
    'branch_ids', to_jsonb(v_row.branch_ids),
    'token', v_row.token,
    'status', v_row.status,
    'invited_by', v_row.invited_by,
    'expires_at', v_row.expires_at,
    'accepted_user_id', v_row.accepted_user_id,
    'created_at', v_row.created_at,
    'resent', v_resent
  );
end;
$$;

grant execute on function public.create_store_invitation(uuid, text, public.store_role, uuid[]) to authenticated;

-- -----------------------------------------------------------------------------
-- Accept invite (franchise owner handoff skips seat limit)
-- -----------------------------------------------------------------------------
create or replace function public.accept_store_invitation(p_token text)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_token text;
  v_inv public.store_invitations;
  v_uid uuid := auth.uid();
  v_email text;
begin
  if v_uid is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  v_token := trim(both from coalesce(p_token, ''));
  v_token := trim(both E' \t\n\r()<>[]{}"''' from v_token);

  if v_token is null or length(v_token) < 8 then
    raise exception 'INVITE_NOT_FOUND';
  end if;

  select email into v_email from auth.users where id = v_uid;

  select * into v_inv
  from public.store_invitations
  where token = v_token
  for update;

  if not found then
    raise exception 'INVITE_NOT_FOUND';
  end if;

  if v_inv.status = 'accepted' then
    raise exception 'INVITE_ALREADY_ACCEPTED:%', v_inv.email;
  end if;

  if v_inv.status is distinct from 'pending' then
    raise exception 'INVITE_NOT_PENDING:%', v_inv.email;
  end if;

  if v_inv.expires_at <= now() then
    raise exception 'INVITE_EXPIRED:%', v_inv.email;
  end if;

  if lower(coalesce(v_email, '')) <> lower(v_inv.email) then
    raise exception 'INVITE_EMAIL_MISMATCH:%', v_inv.email;
  end if;

  if v_inv.role = 'owner' then
    -- Franchise owner handoff: claim store ownership; drop any leftover members.
    delete from public.store_members where store_id = v_inv.store_id;
    update public.stores
    set owner_id = v_uid, updated_at = now()
    where id = v_inv.store_id;
  else
    perform public.assert_free_team_seat_available(
      v_inv.store_id,
      v_email,
      false,
      'accept'
    );
  end if;

  insert into public.store_members (
    store_id, user_id, role, branch_ids, status, invited_by
  ) values (
    v_inv.store_id, v_uid, v_inv.role, v_inv.branch_ids, 'active', v_inv.invited_by
  )
  on conflict (store_id, user_id) do update
    set role = excluded.role,
        branch_ids = excluded.branch_ids,
        status = 'active';

  update public.store_invitations
  set status = 'accepted', accepted_user_id = v_uid
  where id = v_inv.id;

  return v_inv.store_id;
end;
$$;

grant execute on function public.accept_store_invitation(text) to authenticated;

-- Platform ops Free default limit when flipping from premium without explicit limit.
create or replace function public.platform_set_store_plan(
  p_store_id uuid,
  p_plan_tier public.plan_tier,
  p_monthly_limit int default null
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_limit int;
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN' using errcode = 'P0001';
  end if;

  if not exists (select 1 from public.stores where id = p_store_id) then
    raise exception 'STORE_NOT_FOUND' using errcode = 'P0001';
  end if;

  v_limit := coalesce(
    p_monthly_limit,
    case when p_plan_tier = 'premium' then 100000 else 100 end
  );

  update public.stores
  set
    plan_tier = p_plan_tier,
    monthly_transaction_limit = greatest(1, v_limit),
    updated_at = now()
  where id = p_store_id;

  update public.subscriptions
  set
    plan_tier = p_plan_tier,
    status = 'active',
    provider = 'manual',
    updated_at = now()
  where store_id = p_store_id;

  return jsonb_build_object(
    'ok', true,
    'store_id', p_store_id,
    'plan_tier', p_plan_tier,
    'monthly_transaction_limit', v_limit
  );
end;
$$;

grant execute on function public.platform_set_store_plan(uuid, public.plan_tier, int) to authenticated;
