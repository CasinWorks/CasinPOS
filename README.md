# CasinPOS

Flutter POS + inventory for retail and restaurant stores, with a Supabase backend.

## Layout

| Path | What |
|------|------|
| `app/` | Flutter client (web, iOS, Android) |
| `supabase/` | Migrations and `config.toml` |
| `supabase/functions/` | Edge Functions (invite email) |

There is also a legacy Vite/React scaffold at the repo root (`src/`, `package.json`); the product app is Flutter under `app/`.

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (stable, web enabled)
- A [Supabase](https://supabase.com) project
- Optional: a [Resend](https://resend.com) API key for teammate invite emails

## Local setup

1. Apply SQL under `supabase/migrations/` in your Supabase project (CLI or SQL editor).
2. Copy env templates:

```bash
cp .env.example .env
cp app/.env.example app/.env   # optional reference only
```

3. Run the Flutter app from `app/` with dart-defines (do not commit real keys):

```bash
cd app
flutter pub get
flutter run -d chrome \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_URL=http://localhost:XXXX
```

Or pass the values inline. `SUPABASE_URL` and `SUPABASE_ANON_KEY` are read via `String.fromEnvironment` at build time. `APP_URL` is optional (invite share links); on web it defaults to the current origin, otherwise `https://casin-pos-black.vercel.app`.

## Staff / franchise invite emails

Invites still create a row in `store_invitations` via RPC. After create, the app:

1. Builds a join link: `{APP_URL}/invite?token=…` (alias: `/join?token=…`)
2. Calls Edge Function `send-invite-email` (Resend)
3. Always shows **Copy invite link**, **Copy token**, and **Open email draft** (`mailto:`) as backup

### Configure Resend (recommended)

```bash
# From repo root, linked Supabase project:
supabase functions deploy send-invite-email

supabase secrets set RESEND_API_KEY=re_xxxxxxxx
# Optional — verify domain in Resend for production from-address:
supabase secrets set RESEND_FROM_EMAIL="CasinPOS <invites@yourdomain.com>"
supabase secrets set PUBLIC_APP_URL=https://casin-pos-black.vercel.app
```

Without `RESEND_API_KEY`, the function returns `emailed: false` and the UI falls back to copy link / mailto. No paid key required for that path.

### Alternative: Supabase Auth SMTP only

Built-in Auth emails are for signup/recovery, not custom invite tokens. Prefer Resend + this Edge Function so the email includes the CasinPOS join link with the existing invite token.

## Signup / confirm emails (Supabase Auth + optional Resend SMTP)

**Account creation / email verification** does **not** go through `send-invite-email`. Supabase Auth sends those messages using its **Email Templates**. To deliver them through Resend (same provider as staff invites), configure **Custom SMTP**:

1. [Resend](https://resend.com) → API Keys → copy a key.
2. Supabase Dashboard → **Project Settings → Authentication → SMTP Settings** (or **Authentication → SMTP**):
   - Host: `smtp.resend.com`
   - Port: `465` (SSL) or `587` (STARTTLS)
   - Username: `resend`
   - Password: your Resend API key
   - Sender email: a **verified domain** address in production (e.g. `CasinPOS <noreply@yourdomain.com>`).  
     `onboarding@resend.dev` only delivers to **your own** Resend account email.
3. **Authentication → Email Templates → Confirm signup** (may require Custom SMTP first on free tier):
   - Subject: paste from `supabase/email-templates/confirm_signup_subject.txt` (`Welcome to CasinPOS`)
   - Body: paste from `supabase/email-templates/confirm_signup.html`
4. Flutter already passes `full_name` in signup `data` / `userMetadata` so the template can use `{{ .Data.full_name }}`.

Template variables and paste instructions: `supabase/email-templates/README.md`.

| Email type | How it sends |
|------------|--------------|
| Staff / franchise invite | Edge Function → Resend HTTP API |
| Confirm signup / recovery / magic link | Supabase Auth (+ optional Resend SMTP) |

## Vercel (Flutter web)

This repo deploys **Flutter web**, not React.

1. Import [CasinWorks/CasinPOS](https://github.com/CasinWorks/CasinPOS) in the [Vercel dashboard](https://vercel.com/new).
2. Framework preset: **Other** (config is in `vercel.json`).
3. Set environment variables for Production (and Preview if you use it):
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
   - `APP_URL` (optional; production site URL used in invite links at build time)
4. Deploy. The first build often takes several minutes while the Flutter SDK is cloned and compiled.
5. Output is `app/build/web` (see `scripts/vercel_build.sh`).

Root URL deploy uses path URLs (`/invite?token=…`) with SPA rewrites in `vercel.json`.

## License

Private — CasinWorks.
