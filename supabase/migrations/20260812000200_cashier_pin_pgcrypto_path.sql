-- Fix cashier PIN hashing: pgcrypto lives in extensions on Supabase.

create or replace function public.set_my_store_pin(
  p_store_id uuid,
  p_pin text
)
returns void
language plpgsql
security definer
set search_path = public, extensions
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

create or replace function public.verify_member_pin(
  p_store_id uuid,
  p_user_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
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

-- claim_shift_with_pin calls verify_member_pin; keep its search_path consistent.
create or replace function public.claim_shift_with_pin(
  p_session_id uuid,
  p_user_id uuid,
  p_pin text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
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
