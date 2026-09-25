#!/usr/bin/env bash
# Build Flutter web for Vercel (base-href /).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

FLUTTER_ROOT="${FLUTTER_ROOT:-$HOME/flutter}"
CHANNEL="${FLUTTER_CHANNEL:-stable}"

if [[ ! -x "$FLUTTER_ROOT/bin/flutter" ]]; then
  echo "Cloning Flutter ($CHANNEL) into $FLUTTER_ROOT ..."
  rm -rf "$FLUTTER_ROOT"
  git clone https://github.com/flutter/flutter.git \
    --depth 1 \
    -b "$CHANNEL" \
    "$FLUTTER_ROOT"
fi

export PATH="$FLUTTER_ROOT/bin:$PATH"
export PUB_CACHE="${PUB_CACHE:-$HOME/.pub-cache}"

flutter --version
flutter config --no-analytics --enable-web
flutter precache --web
flutter pub get
flutter build web --release --base-href / --pwa-strategy=none

echo "Build output: $ROOT/build/web"
