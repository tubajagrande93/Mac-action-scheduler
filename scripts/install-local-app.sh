#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
SOURCE="$PWD/dist/Mac Action Scheduler.app"
TARGET_DIR="$HOME/Applications"
TARGET="$TARGET_DIR/Mac Action Scheduler.app"
BUNDLE_ID="com.ntstudio.MacActionScheduler"
CERT_NAME="Mac Action Scheduler Local Code Signing"

echo "=== Build ==="
./scripts/build-app.sh

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
mkdir -p "$TARGET_DIR"
if [[ -d "$TARGET" ]]; then
    echo "NOTE: Close the existing Mac Action Scheduler before installing."
fi
rm -rf "$TARGET"
ditto "$SOURCE" "$TARGET"

codesign --verify --deep --strict --verbose=2 "$TARGET"

echo "=== Installed identity ==="
codesign -dv --verbose=4 "$TARGET" 2>&1 | grep -E 'Identifier=|Signature=|Authority=|TeamIdentifier=|CDHash=' || true
codesign -dr - "$TARGET" 2>&1 | tail -n 3

echo ""
echo "PASS: Installed at $TARGET"
echo "Launch with: open \"$TARGET\""
echo "If a previous ad-hoc grant still conflicts, reset ONLY this app:"
echo "  tccutil reset Accessibility $BUNDLE_ID"
