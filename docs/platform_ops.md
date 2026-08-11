# Platform Ops (CasinPOS SaaS admin)

Internal console for CasinWorks admins to support customer stores.

## Enable

1. Apply migration `supabase/migrations/20260811000100_platform_ops.sql` (see `docs/production_sql_paste.md` Script C).
2. Apply Script G for ops depth (notes / messages / audit).
3. Deploy Edge Function `platform-reset-password` (uses existing `RESEND_*` secrets when present).
4. Promote your login email in the SQL Editor:

```sql
select public.platform_set_admin_by_email('you@casinworks.com', true);
```

5. Sign out and back in. Sidebar → **Platform Ops**.

## Capabilities

| Action | Effect |
|--------|--------|
| Search tenants | Name, owner email, store id |
| Set Premium / Free | Updates `stores.plan_tier` + `subscriptions` + monthly limit |
| Suspend / Reinstate | Blocks or restores new sales (`STORE_SUSPENDED`) |
| Support notes | Internal-only admin notes on a tenant |
| Message store | Pushes into store **Notifications** for all active members |
| Reset owner password | Recovery email via Edge Function (+ Resend); otherwise copies link |

## Security

- Gated by `profiles.is_platform_admin`
- RPCs are `security definer` and reject non-admins with `FORBIDDEN`
- Support notes and audit are not readable by tenants
- Store messages readable only by active members of that store
- SQL Editor (`postgres`) can always promote admins
