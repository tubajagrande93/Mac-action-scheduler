#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP="$PWD/dist/Mac Action Scheduler.app"
[[ -d "$APP" ]] || {
    echo "ERROR: Build the app first: bash scripts/build-app.sh" >&2
    exit 1
}

codesign --verify --deep --strict "$APP"
for DOC in README.md LICENSE; do
    [[ -s "$APP/Contents/Resources/$DOC" ]] || {
        echo "ERROR: Missing app-bundled $DOC" >&2
        exit 1
    }
done

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
DMG="$PWD/dist/Mac-Action-Scheduler-$VERSION-macOS.dmg"
STAGE="$(mktemp -d "$PWD/dist/.dmg-stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

ditto "$APP" "$STAGE/Mac Action Scheduler.app"
ln -s /Applications "$STAGE/Applications"
cp README.md LICENSE "$STAGE/"

hdiutil create -quiet -volname "Mac Action Scheduler" \
    -srcfolder "$STAGE" -format UDZO -ov "$DMG"
hdiutil verify -quiet "$DMG"

echo "=== Distribution package ==="
ls -lh "$DMG"
echo "=== SHA-256 ==="
shasum -a 256 "$DMG"
echo "=== Binary architectures ==="
lipo -archs "$APP/Contents/MacOS/MacActionScheduler"
echo "NOTE: This app is locally self-signed, NOT Developer ID notarized."
echo "NOTE: Recipients may see macOS Gatekeeper warnings."
