#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p .build/ModuleCache dist/OpenLid.iconset
swift -module-cache-path .build/ModuleCache scripts/draw-assets.swift Resources
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" Resources/icon.png --out "dist/OpenLid.iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" Resources/icon.png --out "dist/OpenLid.iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns dist/OpenLid.iconset -o Resources/OpenLid.icns
