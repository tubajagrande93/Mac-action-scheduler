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

SIGN_IDENTITY="$(security find-identity -v -p codesigning | sed -n 's/.*"\(Apple Development:[^"]*\)".*/\1/p' | head -n 1)"

if [[ -n "$SIGN_IDENTITY" ]]; then
    codesign --force --sign "$SIGN_IDENTITY" "$APP"
    echo "Signed with Apple Development identity."
else
    codesign --force --sign - "$APP"
    echo "WARNING: Ad-hoc signing used."
    echo "Accessibility permission may need renewal after rebuild."
fi

echo "Verifying signature..."
codesign --verify --verbose=2 "$APP"

echo ""
echo "BUILD COMPLETE"
echo "$APP"
