-- Cashier PIN: store-scoped shift secret for register open / claim.
-- Plaintext never stored. authenticated cannot read pin rows.

create table if not exists public.store_member_pins (
  member_id uuid primary key references public.store_members (id) on delete cascade,
  store_id uuid not null references public.stores (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  pin_hash text not null,
  updated_at timestamptz not null default now(),
  failed_attempts int not null default 0,
  locked_until timestamptz,
  unique (store_id, user_id)
);

create index if not exists store_member_pins_store_id_idx
  on public.store_member_pins (store_id);

alter table public.store_member_pins enable row level security;

revoke all on table public.store_member_pins from anon, authenticated;

-- Extend team list with has_pin (never expose hash).
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
      'is_self', m.user_id = auth.uid(),
      'has_pin', exists (
        select 1 from public.store_member_pins pin where pin.member_id = m.id
      )
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

-- Roster for register claim (any active member of the store).
create or replace function public.list_shift_roster(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_rows jsonb;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if not public.is_store_member(p_store_id) then
    raise exception 'FORBIDDEN';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'user_id', m.user_id,
      'member_id', m.id,
      'role', m.role,
      'full_name', p.full_name,
      'has_pin', exists (
        select 1 from public.store_member_pins pin where pin.member_id = m.id
      ),
      'is_self', m.user_id = auth.uid()
    )
    order by
      case m.role
        when 'owner' then 0
        when 'admin' then 1
        when 'manager' then 2
        else 3
      end,
      p.full_name nulls last
  ), '[]'::jsonb)
  into v_rows
  from public.store_members m
  join public.profiles p on p.id = m.user_id
  where m.store_id = p_store_id
    and m.status = 'active';

  return jsonb_build_object('members', v_rows);
end;
$$;

grant execute on function public.list_shift_roster(uuid) to authenticated;

create or replace function public._assert_pin_format(p_pin text)
returns void
language plpgsql
immutable
as $$
begin
  if p_pin is null or p_pin !~ '^[0-9]{4,6}$' then
    raise exception 'PIN_INVALID'
      using errcode = 'P0001',
            detail = 'PIN must be 4–6 digits.';
  end if;
end;
$$;

-- Self: set / change own PIN for a store membership.
create or replace function public.set_my_store_pin(
  p_store_id uuid,
  p_pin text
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_member_id uuid;
  v_hash text;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  perform public._assert_pin_format(p_pin);

  select id into v_member_id
  from public.store_members
  where store_id = p_store_id
    and user_id = auth.uid()
    and status = 'active';

  if v_member_id is null then
    raise exception 'FORBIDDEN';
  end if;

  v_hash := crypt(p_pin, gen_salt('bf', 10));

  insert into public.store_member_pins (
    member_id, store_id, user_id, pin_hash, updated_at, failed_attempts, locked_until
  ) values (
    v_member_id, p_store_id, auth.uid(), v_hash, now(), 0, null
  )
  on conflict (member_id) do update
    set pin_hash = excluded.pin_hash,
        updated_at = now(),
        failed_attempts = 0,
        locked_until = null;
end;
$$;

grant execute on function public.set_my_store_pin(uuid, text) to authenticated;

-- Owner/admin: clear another member's PIN (they set a new one later).
create or replace function public.admin_clear_member_pin(p_member_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target public.store_members%rowtype;
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

  delete from public.store_member_pins where member_id = p_member_id;
end;
$$;

grant execute on function public.admin_clear_member_pin(uuid) to authenticated;

-- Verify PIN for a store member. Updates lockout counters.
create or replace function public.verify_member_pin(
  p_store_id uuid,
  p_user_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_pin public.store_member_pins%rowtype;
  v_ok boolean;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if not public.is_store_member(p_store_id) then
    raise exception 'FORBIDDEN';
  end if;

  perform public._assert_pin_format(p_pin);

  select * into v_pin
  from public.store_member_pins
  where store_id = p_store_id
    and user_id = p_user_id;

  if not found then
    raise exception 'PIN_NOT_SET'
      using errcode = 'P0001',
            detail = 'This teammate has not set a cashier PIN yet.';
  end if;

  if v_pin.locked_until is not null and v_pin.locked_until > now() then
    raise exception 'PIN_LOCKED'
      using errcode = 'P0001',
            detail = format(
              'Too many wrong PIN attempts. Try again after %s.',
              to_char(v_pin.locked_until at time zone 'UTC', 'HH24:MI" UTC"')
            );
  end if;

  v_ok := (v_pin.pin_hash = crypt(p_pin, v_pin.pin_hash));

  if not v_ok then
    update public.store_member_pins
    set
      failed_attempts = failed_attempts + 1,
      locked_until = case
        when failed_attempts + 1 >= 5 then now() + interval '5 minutes'
        else locked_until
      end
    where member_id = v_pin.member_id;

    raise exception 'PIN_INCORRECT'
      using errcode = 'P0001',
            detail = 'Incorrect PIN.';
  end if;

  update public.store_member_pins
  set failed_attempts = 0, locked_until = null, updated_at = updated_at
  where member_id = v_pin.member_id;

  return jsonb_build_object(
    'ok', true,
    'user_id', p_user_id,
    'store_id', p_store_id
  );
end;
$$;

grant execute on function public.verify_member_pin(uuid, uuid, text) to authenticated;

-- Claim (or re-claim) open session after successful PIN for target cashier.
create or replace function public.claim_shift_with_pin(
  p_session_id uuid,
  p_user_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_session public.cash_sessions%rowtype;
  v_active boolean;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select * into v_session
  from public.cash_sessions
  where id = p_session_id
    and status = 'open';

  if not found then
    raise exception 'SESSION_NOT_OPEN'
      using errcode = 'P0001',
            detail = 'No open register session to claim.';
  end if;

  if not public.is_store_member(v_session.store_id) then
    raise exception 'FORBIDDEN';
  end if;

  select exists (
    select 1 from public.store_members m
    where m.store_id = v_session.store_id
      and m.user_id = p_user_id
      and m.status = 'active'
  ) into v_active;

  if not v_active then
    raise exception 'MEMBER_NOT_FOUND';
  end if;

  perform public.verify_member_pin(v_session.store_id, p_user_id, p_pin);

  update public.cash_sessions
  set
    claimed_by = p_user_id,
    claimed_at = now()
  where id = p_session_id
    and status = 'open';

  return jsonb_build_object(
    'ok', true,
    'session_id', p_session_id,
    'claimed_by', p_user_id,
    'claimed_at', now()
  );
end;
$$;

grant execute on function public.claim_shift_with_pin(uuid, uuid, text) to authenticated;

-- Does the signed-in user have a PIN for this store?
create or replace function public.my_store_pin_status(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_has boolean;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if not public.is_store_member(p_store_id) then
    raise exception 'FORBIDDEN';
  end if;

  select exists (
    select 1 from public.store_member_pins
    where store_id = p_store_id
      and user_id = auth.uid()
  ) into v_has;

  return jsonb_build_object('has_pin', v_has);
end;
$$;

grant execute on function public.my_store_pin_status(uuid) to authenticated;
