#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR/.."

# shellcheck source=install-lib.sh
source "$SCRIPT_DIR/install-lib.sh"

# Overridable for isolated testing; defaults match the normal install layout.
SOURCE="${MAS_SOURCE_APP:-$PWD/dist/Mac Action Scheduler.app}"
TARGET_DIR="${MAS_TARGET_DIR:-$HOME/Applications}"
BUNDLE_ID="com.ntstudio.MacActionScheduler"
CERT_NAME="Mac Action Scheduler Local Code Signing"
EXECUTABLE_NAME="MacActionScheduler"

TARGET="$TARGET_DIR/Mac Action Scheduler.app"
INSTALLED_EXECUTABLE="$TARGET/Contents/MacOS/$EXECUTABLE_NAME"

# Restore on any abnormal exit (including signals) while an install is in
# progress. mas_cleanup is idempotent and only deletes the backup after the
# final bundle has been verified.
trap mas_cleanup EXIT

# Fast-fail: refuse before spending time building.
mas_refuse_if_running "$INSTALLED_EXECUTABLE" || exit 2

echo "=== Build ==="
if [[ "${MAS_SKIP_BUILD:-0}" != "1" ]]; then
    ./scripts/build-app.sh
fi

echo "=== Verify locally signed bundle ==="
codesign --verify --deep --strict --verbose=2 "$SOURCE"
SIGNATURE="$(codesign -dv --verbose=4 "$SOURCE" 2>&1)"
printf '%s\n' "$SIGNATURE" | grep -F "Authority=$CERT_NAME" >/dev/null || {
    echo "ERROR: App was not signed with the expected stable local certificate."
    exit 1
}

ACTUAL_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$SOURCE/Contents/Info.plist")"
if [[ "$ACTUAL_BUNDLE_ID" != "$BUNDLE_ID" ]]; then
    echo "ERROR: Unexpected bundle ID: $ACTUAL_BUNDLE_ID"
    exit 1
fi

echo "=== Install to permanent user Applications location ==="
mas_install "$SOURCE" "$TARGET_DIR" "$BUNDLE_ID" "$EXECUTABLE_NAME"

echo "=== Installed identity ==="
codesign -dv --verbose=4 "$TARGET" 2>&1 | grep -E 'Identifier=|Signature=|Authority=|TeamIdentifier=|CDHash=' || true
codesign -dr - "$TARGET" 2>&1 | tail -n 3

echo ""
echo "PASS: Installed at $TARGET"
echo "Launch with: open \"$TARGET\""
echo "If a previous ad-hoc grant still conflicts, reset ONLY this app:"
echo "  tccutil reset Accessibility $BUNDLE_ID"
