#!/usr/bin/env bash
# Build CasinPOS Flutter web for Vercel.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FLUTTER_DIR="${FLUTTER_DIR:-$HOME/flutter}"
FLUTTER_CHANNEL="${FLUTTER_CHANNEL:-stable}"

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "error: SUPABASE_URL and SUPABASE_ANON_KEY must be set in the Vercel project env." >&2
  exit 1
fi

if [[ ! -x "$FLUTTER_DIR/bin/flutter" ]]; then
  echo "Cloning Flutter ($FLUTTER_CHANNEL) into $FLUTTER_DIR ..."
  rm -rf "$FLUTTER_DIR"
  git clone https://github.com/flutter/flutter.git --depth 1 -b "$FLUTTER_CHANNEL" "$FLUTTER_DIR"
fi

export PATH="$FLUTTER_DIR/bin:$PATH"
export PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"

flutter config --no-analytics
flutter config --enable-web
flutter doctor -v || true

cd "$ROOT_DIR/app"
flutter pub get
flutter build web --release \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY" \
  --dart-define=APP_URL="${APP_URL:-https://casin-pos-black.vercel.app}"

echo "Web build ready at app/build/web"
