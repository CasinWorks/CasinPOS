-- Must run before 20260818000200. Adds branch_manager to store_role.
do $$
begin
  if not exists (
    select 1
    from pg_enum e
    join pg_type t on t.oid = e.enumtypid
    join pg_namespace n on n.oid = t.typnamespace
    where n.nspname = 'public'
      and t.typname = 'store_role'
      and e.enumlabel = 'branch_manager'
  ) then
    alter type public.store_role add value 'branch_manager';
  end if;
end $$;
