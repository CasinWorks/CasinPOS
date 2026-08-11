-- Platform Ops depth: support notes, tenant messages, admin audit log.

create table if not exists public.platform_support_notes (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  author_id uuid not null references public.profiles (id),
  body text not null check (char_length(trim(body)) between 1 and 4000),
  created_at timestamptz not null default now()
);

create index if not exists platform_support_notes_store_created_idx
  on public.platform_support_notes (store_id, created_at desc);

alter table public.platform_support_notes enable row level security;
revoke all on table public.platform_support_notes from anon, authenticated;

create table if not exists public.store_messages (
  id uuid primary key default gen_random_uuid(),
  store_id uuid not null references public.stores (id) on delete cascade,
  subject text not null check (char_length(trim(subject)) between 1 and 120),
  body text not null check (char_length(trim(body)) between 1 and 4000),
  created_by uuid not null references public.profiles (id),
  created_at timestamptz not null default now()
);

create index if not exists store_messages_store_created_idx
  on public.store_messages (store_id, created_at desc);

create table if not exists public.store_message_reads (
  message_id uuid not null references public.store_messages (id) on delete cascade,
  user_id uuid not null references public.profiles (id) on delete cascade,
  read_at timestamptz not null default now(),
  primary key (message_id, user_id)
);

alter table public.store_messages enable row level security;
alter table public.store_message_reads enable row level security;
revoke all on table public.store_messages from anon, authenticated;
revoke all on table public.store_message_reads from anon, authenticated;

create table if not exists public.platform_admin_audit (
  id uuid primary key default gen_random_uuid(),
  admin_id uuid not null references public.profiles (id),
  action text not null,
  store_id uuid references public.stores (id) on delete set null,
  target_user_id uuid references public.profiles (id) on delete set null,
  meta jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index if not exists platform_admin_audit_created_idx
  on public.platform_admin_audit (created_at desc);

alter table public.platform_admin_audit enable row level security;
revoke all on table public.platform_admin_audit from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Support notes
-- ---------------------------------------------------------------------------
create or replace function public.platform_list_support_notes(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_rows jsonb;
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', n.id,
      'body', n.body,
      'created_at', n.created_at,
      'author_id', n.author_id,
      'author_name', p.full_name,
      'author_email', u.email
    )
    order by n.created_at desc
  ), '[]'::jsonb)
  into v_rows
  from (
    select * from public.platform_support_notes
    where store_id = p_store_id
    order by created_at desc
    limit 50
  ) n
  join public.profiles p on p.id = n.author_id
  left join auth.users u on u.id = n.author_id;

  return jsonb_build_object('notes', v_rows);
end;
$$;

grant execute on function public.platform_list_support_notes(uuid) to authenticated;

create or replace function public.platform_add_support_note(
  p_store_id uuid,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_body text := trim(p_body);
  v_row public.platform_support_notes%rowtype;
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN';
  end if;

  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if v_body is null or char_length(v_body) < 1 then
    raise exception 'NOTE_EMPTY';
  end if;

  if not exists (select 1 from public.stores where id = p_store_id) then
    raise exception 'STORE_NOT_FOUND';
  end if;

  insert into public.platform_support_notes (store_id, author_id, body)
  values (p_store_id, auth.uid(), v_body)
  returning * into v_row;

  return jsonb_build_object(
    'ok', true,
    'id', v_row.id,
    'body', v_row.body,
    'created_at', v_row.created_at
  );
end;
$$;

grant execute on function public.platform_add_support_note(uuid, text) to authenticated;

-- ---------------------------------------------------------------------------
-- Tenant messages (ops → store members)
-- ---------------------------------------------------------------------------
create or replace function public.platform_send_store_message(
  p_store_id uuid,
  p_subject text,
  p_body text
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_subject text := trim(p_subject);
  v_body text := trim(p_body);
  v_row public.store_messages%rowtype;
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN';
  end if;

  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  if v_subject is null or char_length(v_subject) < 1 then
    raise exception 'SUBJECT_EMPTY';
  end if;
  if v_body is null or char_length(v_body) < 1 then
    raise exception 'MESSAGE_EMPTY';
  end if;

  if not exists (select 1 from public.stores where id = p_store_id) then
    raise exception 'STORE_NOT_FOUND';
  end if;

  insert into public.store_messages (store_id, subject, body, created_by)
  values (p_store_id, v_subject, v_body, auth.uid())
  returning * into v_row;

  insert into public.platform_admin_audit (admin_id, action, store_id, meta)
  values (
    auth.uid(),
    'store_message',
    p_store_id,
    jsonb_build_object('message_id', v_row.id, 'subject', v_subject)
  );

  return jsonb_build_object(
    'ok', true,
    'id', v_row.id,
    'subject', v_row.subject,
    'created_at', v_row.created_at
  );
end;
$$;

grant execute on function public.platform_send_store_message(uuid, text, text) to authenticated;

create or replace function public.platform_list_store_messages(p_store_id uuid)
returns jsonb
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  v_rows jsonb;
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN';
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', m.id,
      'subject', m.subject,
      'body', m.body,
      'created_at', m.created_at,
      'created_by', m.created_by
    )
    order by m.created_at desc
  ), '[]'::jsonb)
  into v_rows
  from (
    select * from public.store_messages
    where store_id = p_store_id
    order by created_at desc
    limit 50
  ) m;

  return jsonb_build_object('messages', v_rows);
end;
$$;

grant execute on function public.platform_list_store_messages(uuid) to authenticated;

create or replace function public.list_my_store_messages(p_store_id uuid)
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
      'id', m.id,
      'subject', m.subject,
      'body', m.body,
      'created_at', m.created_at,
      'is_read', exists (
        select 1 from public.store_message_reads r
        where r.message_id = m.id and r.user_id = auth.uid()
      )
    )
    order by m.created_at desc
  ), '[]'::jsonb)
  into v_rows
  from (
    select * from public.store_messages
    where store_id = p_store_id
    order by created_at desc
    limit 50
  ) m;

  return jsonb_build_object('messages', v_rows);
end;
$$;

grant execute on function public.list_my_store_messages(uuid) to authenticated;

create or replace function public.mark_store_message_read(p_message_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_store_id uuid;
begin
  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  select store_id into v_store_id
  from public.store_messages
  where id = p_message_id;

  if v_store_id is null then
    raise exception 'MESSAGE_NOT_FOUND';
  end if;

  if not public.is_store_member(v_store_id) then
    raise exception 'FORBIDDEN';
  end if;

  insert into public.store_message_reads (message_id, user_id)
  values (p_message_id, auth.uid())
  on conflict (message_id, user_id) do nothing;

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.mark_store_message_read(uuid) to authenticated;

-- Audit helper (also used by edge function via service role / authenticated admin).
create or replace function public.platform_log_audit(
  p_action text,
  p_store_id uuid default null,
  p_target_user_id uuid default null,
  p_meta jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_platform_admin() then
    raise exception 'FORBIDDEN';
  end if;

  if auth.uid() is null then
    raise exception 'NOT_AUTHENTICATED';
  end if;

  insert into public.platform_admin_audit (admin_id, action, store_id, target_user_id, meta)
  values (auth.uid(), trim(p_action), p_store_id, p_target_user_id, coalesce(p_meta, '{}'::jsonb));

  return jsonb_build_object('ok', true);
end;
$$;

grant execute on function public.platform_log_audit(text, uuid, uuid, jsonb) to authenticated;
