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
| Usage overview | Stores active today/7d, paid txn counts, GMV (Asia/Manila day) |
| Recent transactions | Global or per-store feed, **10 per page**, tap for line items |

Also apply `supabase/migrations/20260921000100_platform_recent_transactions.sql`
(`platform_usage_overview`, `platform_list_recent_transactions`).

Web store signup on pos.casinworks.com requires **₱199 PayMongo** (`pending_web` → Premium). See Script O in `docs/production_sql_paste.md`.

## Security

- Gated by `profiles.is_platform_admin`
- RPCs are `security definer` and reject non-admins with `FORBIDDEN`
- Support notes and audit are not readable by tenants
- Store messages readable only by active members of that store
- SQL Editor (`postgres`) can always promote admins
