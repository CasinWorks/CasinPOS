# Platform Ops (CasinPOS SaaS admin)

Internal console for CasinWorks admins to support customer stores.

## Enable

1. Apply migration `supabase/migrations/20260811000100_platform_ops.sql` (see `docs/production_sql_paste.md` Script C).
2. Promote your login email in the SQL Editor:

```sql
select public.platform_set_admin_by_email('you@casinworks.com', true);
```

3. Sign out and back in. Sidebar → **Platform Ops**.

## Capabilities (v1)

| Action | Effect |
|--------|--------|
| Search tenants | Name, owner email, store id |
| Set Premium / Free | Updates `stores.plan_tier` + `subscriptions` + monthly limit |
| Suspend | Blocks new sales (`STORE_SUSPENDED`) |
| Reinstate | Clears suspension |

## Security

- Gated by `profiles.is_platform_admin`
- RPCs are `security definer` and reject non-admins with `FORBIDDEN`
- SQL Editor (`postgres`) can always promote admins
