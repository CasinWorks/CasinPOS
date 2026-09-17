#!/usr/bin/env bash
# Build a macOS release app for Mac App Store / local Test.
# Requires Supabase dart-defines (same as iOS IPA).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env.flutter.local"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "error: Missing $ENV_FILE" >&2
  echo "Create it with SUPABASE_URL, SUPABASE_ANON_KEY, APP_URL=https://pos.casinworks.com" >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
# shellcheck source=/dev/null
source "$ENV_FILE"
set +a

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "error: SUPABASE_URL and SUPABASE_ANON_KEY required in $ENV_FILE" >&2
  exit 1
fi

cd "$ROOT/app"

echo "Building macOS release with dart-defines from $ENV_FILE …"
flutter build macos --release \
  --dart-define-from-file="$ENV_FILE"

echo
echo "App ready at: app/build/macos/Build/Products/Release/casinpos.app"
echo "Then open macos/Runner.xcworkspace → Product → Archive → Distribute."
echo "Release.entitlements must include com.apple.security.network.client (sandboxed Mac App Store)."
