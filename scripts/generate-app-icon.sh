#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."

SOURCE="Assets/MacActionScheduler-Icon.png"
ICONSET="Assets/MacActionScheduler.iconset"
OUTPUT="Assets/MacActionScheduler.icns"

test -f "$SOURCE" || {
    echo "ERROR: Processed icon PNG missing."
    exit 1
}

mkdir -p "$ICONSET"

for SIZE in 16 32 128 256 512; do
    DOUBLE=$((SIZE * 2))

    sips -z "$SIZE" "$SIZE" "$SOURCE" \
      --out "$ICONSET/icon_${SIZE}x${SIZE}.png" >/dev/null

    sips -z "$DOUBLE" "$DOUBLE" "$SOURCE" \
      --out "$ICONSET/icon_${SIZE}x${SIZE}@2x.png" >/dev/null
done

iconutil -c icns "$ICONSET" -o "$OUTPUT"

rm -rf "$ICONSET"

echo "PASS: $OUTPUT"
ls -lh "$OUTPUT"
