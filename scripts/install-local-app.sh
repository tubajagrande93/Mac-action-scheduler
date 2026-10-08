#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
SOURCE="$PWD/dist/Mac Action Scheduler.app"
TARGET_DIR="$HOME/Applications"
TARGET="$TARGET_DIR/Mac Action Scheduler.app"
BUNDLE_ID="com.ntstudio.MacActionScheduler"
CERT_NAME="Mac Action Scheduler Local Code Signing"
EXECUTABLE_NAME="MacActionScheduler"

# Refuse to overwrite the installed app while its executable is running:
# a scheduled click may be pending, and replacing the bundle would silently
# destroy that job. This matches the exact installed binary, not dev builds.
INSTALLED_EXECUTABLE="$TARGET/Contents/MacOS/$EXECUTABLE_NAME"
if [[ -x "$INSTALLED_EXECUTABLE" ]] && pgrep -f "$INSTALLED_EXECUTABLE" >/dev/null 2>&1; then
    echo "ERROR: The installed Mac Action Scheduler is currently running." >&2
    echo "A scheduled click may be pending; refusing to overwrite it." >&2
    echo "Quit the app (or wait for any active job to finish) and try again." >&2
    exit 2
fi

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

echo "=== Stage new bundle before replacing the target ==="
mkdir -p "$TARGET_DIR"

STAGING_DIR="$(mktemp -d "$TARGET_DIR/.mac-action-scheduler.staging.XXXXXX")"
BACKUP_DIR=""
cleanup() {
    rm -rf "$STAGING_DIR"
    [[ -n "$BACKUP_DIR" ]] && rm -rf "$BACKUP_DIR"
}
trap cleanup EXIT

# Copy the freshly built bundle into a temporary sibling and validate it in
# place, so a failed copy or a bad signature never destroys the target.
ditto "$SOURCE" "$STAGING_DIR/Mac Action Scheduler.app"

codesign --verify --deep --strict --verbose=2 "$STAGING_DIR/Mac Action Scheduler.app"
STAGED_BUNDLE_ID="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$STAGING_DIR/Mac Action Scheduler.app/Contents/Info.plist")"
if [[ "$STAGED_BUNDLE_ID" != "$BUNDLE_ID" ]]; then
    echo "ERROR: Staged bundle has unexpected bundle ID: $STAGED_BUNDLE_ID" >&2
    exit 1
fi

# Preserve the previous version until the replacement is fully in place.
if [[ -d "$TARGET" ]]; then
    BACKUP_DIR="$(mktemp -d "$TARGET_DIR/.mac-action-scheduler.backup.XXXXXX")"
    mv "$TARGET" "$BACKUP_DIR/Mac Action Scheduler.app"
fi

if ! mv "$STAGING_DIR/Mac Action Scheduler.app" "$TARGET"; then
    # Restore the previous version so the user is never left without an app.
    if [[ -n "$BACKUP_DIR" && -d "$BACKUP_DIR/Mac Action Scheduler.app" ]]; then
        mv "$BACKUP_DIR/Mac Action Scheduler.app" "$TARGET"
    fi
    echo "ERROR: Could not move the staged bundle into place; previous version restored." >&2
    exit 1
fi

echo "=== Verify installed bundle ==="
codesign --verify --deep --strict --verbose=2 "$TARGET"

echo "=== Installed identity ==="
codesign -dv --verbose=4 "$TARGET" 2>&1 | grep -E 'Identifier=|Signature=|Authority=|TeamIdentifier=|CDHash=' || true
codesign -dr - "$TARGET" 2>&1 | tail -n 3

echo ""
echo "PASS: Installed at $TARGET"
echo "Launch with: open \"$TARGET\""
echo "If a previous ad-hoc grant still conflicts, reset ONLY this app:"
echo "  tccutil reset Accessibility $BUNDLE_ID"
