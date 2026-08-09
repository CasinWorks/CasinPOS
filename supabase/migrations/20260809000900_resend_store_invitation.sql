-- Resend pending store invitations instead of crashing on
-- unique index store_invitations_pending_unique (store_id, email) WHERE status = 'pending'.
--
-- Apply in Supabase SQL Editor if CLI is not linked, then re-invite from the app.

-- Return type changes from store_invitations → jsonb (adds resent flag).
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

  -- Admin may invite manager/staff only (not another admin) unless caller is owner
  if public.member_role(p_store_id) = 'admin' and p_role = 'admin' then
    raise exception 'ADMIN_CANNOT_INVITE_ADMIN';
  end if;

  if v_email is null or position('@' in v_email) < 2 then
    raise exception 'EMAIL_INVALID';
  end if;

  select * into v_row
  from public.store_invitations
  where store_id = p_store_id
    and email = v_email
    and status = 'pending'
  for update;

  if found then
    -- Reuse token so previously shared links still work; extend expiry + refresh role.
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

-- Note: franchise owner invites use a *new* child store_id per create_franchise_store,
-- so store_invitations_pending_unique does not fire on a second franchise for the same email.
-- Staff/teammate re-invites for the same store go through create_store_invitation above.
