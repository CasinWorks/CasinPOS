# CasinPOS

Flutter POS + inventory for retail and restaurant stores, with a Supabase backend.

## Layout

| Path | What |
|------|------|
| `app/` | Flutter client (web, iOS, Android) |
| `supabase/` | Migrations and `config.toml` |

There is also a legacy Vite/React scaffold at the repo root (`src/`, `package.json`); the product app is Flutter under `app/`.

## Prerequisites

- [Flutter](https://docs.flutter.dev/get-started/install) (stable, web enabled)
- A [Supabase](https://supabase.com) project

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
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
```

Or pass the values inline. `SUPABASE_URL` and `SUPABASE_ANON_KEY` are read via `String.fromEnvironment` at build time.

## Vercel (Flutter web)

This repo deploys **Flutter web**, not React.

1. Import [CasinWorks/CasinPOS](https://github.com/CasinWorks/CasinPOS) in the [Vercel dashboard](https://vercel.com/new).
2. Framework preset: **Other** (config is in `vercel.json`).
3. Set environment variables for Production (and Preview if you use it):
   - `SUPABASE_URL`
   - `SUPABASE_ANON_KEY`
4. Deploy. The first build often takes several minutes while the Flutter SDK is cloned and compiled.
5. Output is `app/build/web` (see `scripts/vercel_build.sh`).

Root URL deploy uses the default Flutter base href (`/`).

## License

Private — CasinWorks.
