-- Clearer accept_store_invitation errors (expired vs accepted vs mismatch vs missing)
-- and light token sanitization for email-client / paste artifacts.
--
-- Apply in Supabase SQL Editor if CLI is not linked, then have the owner resend the invite.

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

  -- Trim + strip wrapping punctuation email clients / markdown often add.
  v_token := trim(both from coalesce(p_token, ''));
  v_token := trim(both E' \t\n\r()<>[]{}"''' from v_token);

  if v_token is null or length(v_token) < 8 then
    raise exception 'INVITE_NOT_FOUND';
  end if;

  select email into v_email from auth.users where id = v_uid;

  -- Lookup by token only (any status) so we can distinguish reasons.
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
