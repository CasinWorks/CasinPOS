# CasinPOS Auth email templates

Paste these into the Supabase Dashboard (or apply via Management API after Custom SMTP is enabled).

**Signup / confirm email** is sent by **Supabase Auth**, not the `send-invite-email` Edge Function.

> Free-tier projects on the **default** Supabase mailer often **block** custom template edits until you configure **Custom SMTP** (e.g. Resend). Set SMTP first, then paste or PATCH the template.

| Template file | Dashboard location |
|---------------|-------------------|
| `confirm_signup.html` + `confirm_signup_subject.txt` | Authentication → Email Templates → **Confirm signup** |
| `recovery.html` + `recovery_subject.txt` | Authentication → Email Templates → **Reset password** |

Also add redirect URL allow-list entry:

`https://YOUR_APP_ORIGIN/reset-password`

(and local/dev origins if needed).

## Variables (Go templates)

Confirm signup supports:

| Variable | Meaning |
|----------|---------|
| `{{ .ConfirmationURL }}` | Email verification link (required) |
| `{{ .Email }}` | User email |
| `{{ .SiteURL }}` | Project Site URL |
| `{{ .Token }}` | 6–8 digit OTP (optional alternative to link) |
| `{{ .TokenHash }}` | Hashed token |
| `{{ .Data }}` | `user_metadata` from signup (`data: { … }`) |
| `{{ .Data.full_name }}` | Set by Flutter `signUp` → `data: {'full_name': …}` |

There is **no** `storeName` / `year` helper at confirm time (store is created after verify). Year is hardcoded **2026**.

## Staff invites (separate path)

Teammate / franchise invites use Edge Function `send-invite-email` + Resend API. See root `README.md` and `supabase/functions/send-invite-email/`.
