#!/usr/bin/env bash
#
# reset-pods.sh — clean CocoaPods + Flutter build state after switching SDK versions.
#
# Run this right after `git checkout <version/tag/branch>`, before `flutter run`.
# It fixes the two failure modes that bite when hopping between SDK versions:
#   1. Stale example/ios/Podfile.lock  -> exact-pin conflicts ("could not find
#      compatible versions for Google-Mobile-Ads-SDK / AudienzziOSSDK ...").
#      `pod repo update` does NOT fix this — the lock file is the problem.
#   2. Stale example/build/ headers    -> "Redefinition of
#      'PBMOpenMeasurementFriendlyObstructionPurpose'" from a previous
#      PrebidMobile version's generated -Swift.h.
#
# Usage:
#   ./reset-pods.sh            # clear stale state; next `flutter run/build` does pod install
#   ./reset-pods.sh --install  # also run `pod install` now
#
set -euo pipefail

# CocoaPods needs a UTF-8 locale or `pod install` throws on non-ASCII output.
export LANG=en_US.UTF-8
export LC_ALL=en_US.UTF-8

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
EXAMPLE_DIR="$SCRIPT_DIR/example"

if [ ! -d "$EXAMPLE_DIR/ios" ]; then
  echo "error: $EXAMPLE_DIR/ios not found — run this from the audienzz-flutter-sdk repo root." >&2
  exit 1
fi

echo "==> Removing stale CocoaPods state (Podfile.lock, Pods/)"
rm -rf "$EXAMPLE_DIR/ios/Podfile.lock" "$EXAMPLE_DIR/ios/Pods"

echo "==> flutter clean (wipes stale build/ headers)"
( cd "$EXAMPLE_DIR" && flutter clean >/dev/null )

echo "==> flutter pub get"
( cd "$EXAMPLE_DIR" && flutter pub get >/dev/null )

if [ "${1:-}" = "--install" ]; then
  echo "==> pod install"
  ( cd "$EXAMPLE_DIR/ios" && pod install )
fi

echo "==> Done. Next:  cd example && flutter run"
