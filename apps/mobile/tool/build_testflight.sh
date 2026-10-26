#!/usr/bin/env bash
# Build a TestFlight / App Store IPA with staging (or production) env baked in.
#
# Usage (from apps/mobile):
#   bash tool/build_testflight.sh              # APP_ENV=staging (default)
#   bash tool/build_testflight.sh production
#
# Then open build/ios/archive/*.xcarchive in Xcode Organizer → Distribute App
# → App Store Connect, or upload the IPA under build/ios/ipa/.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_NAME="${1:-staging}"
case "$ENV_NAME" in
  staging|production) ;;
  *)
    echo "Usage: $0 [staging|production]" >&2
    exit 1
    ;;
esac

# Bump build number tip: edit pubspec.yaml version (1.0.0+N) before each upload.
echo "→ flutter build ipa --dart-define=APP_ENV=${ENV_NAME}"
flutter build ipa \
  --release \
  --dart-define="APP_ENV=${ENV_NAME}" \
  --export-method app-store

echo
echo "✅ Archive / IPA ready under build/ios/"
echo "   Organizer should show product name: Huhu"
echo "   Home screen name stays: 呼呼 · 枕边故事 (CFBundleDisplayName)"
echo "   Upload to App Store Connect → TestFlight."
