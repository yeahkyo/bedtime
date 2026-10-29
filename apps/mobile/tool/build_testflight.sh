#!/usr/bin/env bash
# Build a TestFlight / App Store IPA with staging (or production) env baked in.
#
# Usage (from apps/mobile):
#   bash tool/build_testflight.sh                 # staging, export IPA only (no upload)
#   bash tool/build_testflight.sh production      # production, export only
#   bash tool/build_testflight.sh --upload        # staging + upload once to ASC
#   bash tool/build_testflight.sh production --upload
#
# IMPORTANT: ExportOptions-upload.plist sets destination=upload. Never run a second
# xcodebuild -exportArchive with that plist after this script already uploaded —
# that causes duplicate / redundant binary uploads on App Store Connect.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

ENV_NAME="staging"
DO_UPLOAD=0

usage() {
  cat <<EOF
Usage: $(basename "$0") [staging|production] [--upload]

  (default)     Build App Store IPA only (no upload).
  --upload      Build and upload once via ios/ExportOptions-upload.plist.
                Do not re-run xcodebuild exportArchive afterward.

Bump pubspec.yaml version (1.0.0+N) before each App Store Connect upload.
EOF
  exit 1
}

for arg in "$@"; do
  case "$arg" in
    -h|--help) usage ;;
    --upload) DO_UPLOAD=1 ;;
    staging|production) ENV_NAME="$arg" ;;
    *)
      echo "Unknown argument: $arg" >&2
      usage
      ;;
  esac
done

UPLOAD_PLIST="$ROOT/ios/ExportOptions-upload.plist"
if [[ "$DO_UPLOAD" -eq 1 && ! -f "$UPLOAD_PLIST" ]]; then
  echo "Missing $UPLOAD_PLIST" >&2
  exit 1
fi

# Bump build number tip: edit pubspec.yaml version (1.0.0+N) before each upload.
if [[ "$DO_UPLOAD" -eq 1 ]]; then
  echo "→ flutter build ipa (APP_ENV=${ENV_NAME}) + single ASC upload"
  echo "   (ExportOptions destination=upload — do not exportArchive again)"
  flutter build ipa \
    --release \
    --dart-define="APP_ENV=${ENV_NAME}" \
    --export-options-plist="$UPLOAD_PLIST"
  echo
  echo "✅ Upload finished (or in progress on App Store Connect)."
  echo "   Version from pubspec; check TestFlight — do NOT run a second upload"
  echo "   with ExportOptions-upload.plist / exportArchive for this build number."
else
  echo "→ flutter build ipa (APP_ENV=${ENV_NAME}, export only — no upload)"
  flutter build ipa \
    --release \
    --dart-define="APP_ENV=${ENV_NAME}" \
    --export-method app-store
  echo
  echo "✅ Archive / IPA ready under build/ios/"
  echo "   Organizer product name: Huhu"
  echo "   Display name: 呼呼 · 枕边故事"
  echo "   Upload once via: Organizer / Transporter, or:"
  echo "     bash tool/build_testflight.sh ${ENV_NAME} --upload"
  echo "   (Do not combine Organizer upload with --upload for the same +N.)"
fi
