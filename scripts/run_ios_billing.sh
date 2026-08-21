#!/usr/bin/env bash
# Run CasinPOS on iOS Simulator / device with Supabase + RevenueCat keys.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ENV_FILE="$ROOT/.env.flutter.local"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "Missing $ENV_FILE — copy keys from docs/revenuecat_setup.md"
  exit 1
fi
cd "$ROOT/app"
DEVICE="${1:-}"
if [[ -n "$DEVICE" ]]; then
  exec flutter run -d "$DEVICE" --dart-define-from-file="$ENV_FILE"
else
  exec flutter run --dart-define-from-file="$ENV_FILE"
fi
