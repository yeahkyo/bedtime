#!/usr/bin/env bash
# Regenerate native splash from extinguished logo; size/position match Flutter SplashLayout.
# Run from apps/mobile/:  bash tool/regenerate_native_splash.sh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="$ROOT/assets/branding/splash_logo_dark.png"
# Must match SplashColors.logoSize (logical pt).
LOGO_PT=88

if [[ ! -f "$SRC" ]]; then
  echo "Missing $SRC — convert design/logo_dark.jpeg first." >&2
  exit 1
fi

# Bake rounded corners (splash bg fill) so iOS open-zoom / native splash match Flutter ClipRRect.
ROUND_PY="${ROUND_PY:-}"
if [[ -z "$ROUND_PY" ]]; then
  if [[ -x /tmp/pilvenv/bin/python ]]; then
    ROUND_PY=/tmp/pilvenv/bin/python
  else
    ROUND_PY=python3
  fi
fi
"$ROUND_PY" "$ROOT/tool/round_splash_logo.py" "$SRC" "$ROOT/assets/branding/splash_logo.png"

(cd "$ROOT" && dart run flutter_native_splash:create && dart run tool/patch_native_splash.dart)

resize() {
  local px="$1" out="$2"
  mkdir -p "$(dirname "$out")"
  sips -z "$px" "$px" "$SRC" --out "$out" >/dev/null
  # Re-apply mask after downscale — resampling otherwise softens/eats corner transparency.
  "$ROUND_PY" "$ROOT/tool/round_splash_logo.py" "$out"
}

RES="$ROOT/android/app/src/main/res"
# Density buckets → intrinsic size ≈ LOGO_PT dp
declare -a SPECS=(
  "drawable-mdpi:$((LOGO_PT * 1))"
  "drawable-hdpi:$((LOGO_PT * 3 / 2))"
  "drawable-xhdpi:$((LOGO_PT * 2))"
  "drawable-xxhdpi:$((LOGO_PT * 3))"
  "drawable-xxxhdpi:$((LOGO_PT * 4))"
)

for spec in "${SPECS[@]}"; do
  dir="${spec%%:*}"
  px="${spec##*:}"
  resize "$px" "$RES/$dir/splash.png"
  cp "$RES/$dir/splash.png" "$RES/$dir/android12splash.png"
  night="${dir/drawable-/drawable-night-}"
  mkdir -p "$RES/$night"
  cp "$RES/$dir/splash.png" "$RES/$night/splash.png"
  cp "$RES/$dir/splash.png" "$RES/$night/android12splash.png"
done

IOS="$ROOT/ios/Runner/Assets.xcassets/LaunchImage.imageset"
resize $((LOGO_PT * 1)) "$IOS/LaunchImage.png"
resize $((LOGO_PT * 2)) "$IOS/LaunchImage@2x.png"
resize $((LOGO_PT * 3)) "$IOS/LaunchImage@3x.png"

echo "Native splash images forced to ${LOGO_PT}pt (dark / extinguished logo)."
