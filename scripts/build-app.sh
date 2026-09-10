#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export CLANG_MODULE_CACHE_PATH="$PWD/.build/ModuleCache"
export SWIFTPM_MODULECACHE_OVERRIDE="$PWD/.build/ModuleCache"
SWIFT_FLAGS=(--disable-sandbox --scratch-path .build --cache-path .build/cache --config-path .build/config --security-path .build/security)
swift build -c release --product OpenLid "${SWIFT_FLAGS[@]}"
BIN_DIR="$(swift build -c release "${SWIFT_FLAGS[@]}" --show-bin-path)"
APP_DIR="$PWD/dist/OpenLid.app"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_DIR/OpenLid" "$APP_DIR/Contents/MacOS/OpenLid"
cp Resources/Info.plist "$APP_DIR/Contents/Info.plist"
cp Resources/OpenLid.icns "$APP_DIR/Contents/Resources/OpenLid.icns"
cp LICENSE "$APP_DIR/Contents/Resources/LICENSE.txt"
cp Resources/DMG-README.txt "$APP_DIR/Contents/Resources/Read me first.txt"
codesign --force --sign - "$APP_DIR"
printf 'Built %s\n' "$APP_DIR"
