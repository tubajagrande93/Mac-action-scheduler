#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

APP_NAME="Mac Action Scheduler"
BUNDLE_ID="com.ntstudio.MacActionScheduler"

echo "Building Swift application..."
swift build -c debug --product MacActionScheduler

BIN_DIR="$(swift build -c debug --show-bin-path)"
APP="$PWD/dist/$APP_NAME.app"

echo "Creating macOS app bundle..."

rm -rf "$APP"

mkdir -p "$APP/Contents/MacOS"
mkdir -p "$APP/Contents/Resources"

ICON_SOURCE="$PWD/Assets/MacActionScheduler.icns"

if [[ ! -f "$ICON_SOURCE" ]]; then
    echo "ERROR: App icon missing."
    echo "Run: bash scripts/generate-app-icon.sh"
    exit 1
fi

cp "$ICON_SOURCE"    "$APP/Contents/Resources/MacActionScheduler.icns"

cp "$BIN_DIR/MacActionScheduler" \
   "$APP/Contents/MacOS/MacActionScheduler"

chmod +x "$APP/Contents/MacOS/MacActionScheduler"

# Copy Swift Package Manager resource bundles.
find "$BIN_DIR" -maxdepth 1 -type d -name '*.bundle' \
    -exec cp -R {} "$APP/Contents/Resources/" \;

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>MacActionScheduler</string>

    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>

    <key>CFBundleName</key>
    <string>$APP_NAME</string>

    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>

    <key>CFBundleIconFile</key>
    <string>MacActionScheduler.icns</string>

    <key>CFBundlePackageType</key>
    <string>APPL</string>

    <key>CFBundleShortVersionString</key>
    <string>0.2.0</string>

    <key>CFBundleVersion</key>
    <string>2</string>

    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>

    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "Validating Info.plist..."
plutil -lint "$APP/Contents/Info.plist"

echo "Signing application..."

LOCAL_NAME="Mac Action Scheduler Local Code Signing"

# Prefer the stable local identity for consistent macOS TCC recognition.
LOCAL_SHA="$(security find-identity -v -p codesigning | awk -v name="\"$LOCAL_NAME\"" 'index($0, name) { print $2; exit }')"
APPLE_SHA="$(security find-identity -v -p codesigning | awk '/"Apple Development:/ { print $2; exit }')"

if [[ -n "$LOCAL_SHA" ]]; then
    codesign --force --timestamp=none --sign "$LOCAL_SHA" "$APP"
    echo "SIGNED: Stable local certificate ($LOCAL_NAME)"
elif [[ -n "$APPLE_SHA" ]]; then
    codesign --force --timestamp=none --sign "$APPLE_SHA" "$APP"
    echo "SIGNED: Apple Development identity"
else
    codesign --force --sign - "$APP"
    echo "WARNING: No code-signing identity found; ad-hoc signature used."
    echo "For stable Accessibility permission, run:"
    echo "  bash scripts/setup-local-signing.sh"
fi

echo "Verifying signature..."
codesign --verify --verbose=2 "$APP"

codesign -dv --verbose=4 "$APP" 2>&1 | grep -E "Identifier=|Signature=|Authority=|TeamIdentifier=" || true
codesign -dr - "$APP" 2>&1 | tail -n 3

echo ""
echo "BUILD COMPLETE"
echo "$APP"
