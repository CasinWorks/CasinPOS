# send-invite-email

Emails a CasinPOS join link for a pending `store_invitations` token (Resend).

## Deploy

```bash
supabase functions deploy send-invite-email
supabase secrets set RESEND_API_KEY=re_xxxxxxxx
supabase secrets set PUBLIC_APP_URL=https://casin-pos-black.vercel.app
# optional:
supabase secrets set RESEND_FROM_EMAIL="CasinPOS <invites@yourdomain.com>"
```

Without `RESEND_API_KEY`, the function returns `{ emailed: false, invite_url }` so the Flutter app can still show copy-link / mailto.
