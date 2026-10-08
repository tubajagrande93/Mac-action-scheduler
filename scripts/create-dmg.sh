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
ARCHS="$(lipo -archs "$APP/Contents/MacOS/MacActionScheduler")"
ARCH_TAG="$ARCHS"
if [[ " $ARCHS " == *" arm64 "* && " $ARCHS " == *" x86_64 "* ]]; then
    ARCH_TAG="universal"
fi
ARCH_TAG="${ARCH_TAG// /-}"
DMG="$PWD/dist/Mac-Action-Scheduler-$VERSION-macOS-$ARCH_TAG.dmg"
STAGE="$(mktemp -d "$PWD/dist/.dmg-stage.XXXXXX")"
trap 'rm -rf "$STAGE"' EXIT

ditto "$APP" "$STAGE/Mac Action Scheduler.app"
ln -s /Applications "$STAGE/Applications"
cp README.md LICENSE "$STAGE/"
cat > "$STAGE/INSTALL.txt" <<'GUIDE'
MAC ACTION SCHEDULER - FREE NONCOMMERCIAL EDITION

1. Drag "Mac Action Scheduler.app" to "Applications".
2. Open it from Applications.
3. Because this free build is not Apple-notarized, macOS may block
   the first launch. If you trust this download, try to open it and
   then choose System Settings > Privacy & Security > Open Anyway.
   Do not disable Gatekeeper globally.
4. Grant the requested Accessibility and click-event permissions.
5. Keep the app running for scheduled clicks; quitting cancels them.

This software is free to share under PolyForm Noncommercial 1.0.0.
See LICENSE and README.md for full terms and limitations.
GUIDE

hdiutil create -quiet -volname "Mac Action Scheduler" \
    -srcfolder "$STAGE" -format UDZO -ov "$DMG"
hdiutil verify -quiet "$DMG"

echo "=== Distribution package ==="
ls -lh "$DMG"
echo "=== SHA-256 ==="
shasum -a 256 "$DMG"
echo "=== Binary architectures ==="
echo "$ARCHS"
echo "NOTE: This app is signed using the existing local build identity (or an ad-hoc fallback), NOT Developer ID notarized."
echo "NOTE: Recipients may see macOS Gatekeeper warnings."
