#!/usr/bin/env bash
# Build a release IPA for App Store / TestFlight (paid app — no IAP).
# Requires Supabase dart-defines. RevenueCat keys are optional (IAP disabled).
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

echo "Building App Store IPA with dart-defines from $ENV_FILE …"
flutter build ipa --release \
  --dart-define-from-file="$ENV_FILE"

echo
echo "IPA ready under app/build/ios/ipa/"
echo "Upload via Xcode Organizer or Transporter."
echo
echo "Before App Review resubmit:"
echo "  1. App Store Connect → Pricing → set app price to ₱199"
echo "  2. Remove ALL In-App Purchases from this version (no casinpos_premium_*)"
echo "  3. Review notes: paid app ₱199, no IAP, full access after install"
echo "  4. See docs/app_store_listing.md"
