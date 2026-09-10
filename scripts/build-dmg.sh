#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-app.sh
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' dist/OpenLid.app/Contents/Info.plist)"
ARCH="$(lipo -archs dist/OpenLid.app/Contents/MacOS/OpenLid | tr ' ' '-')"
NAME="OpenLid-${VERSION}-alpha.1-${ARCH}.dmg"
STAGING="$(mktemp -d "$PWD/dist/dmg-stage.XXXXXX")"
trap 'rm -rf "$STAGING"' EXIT
ditto dist/OpenLid.app "$STAGING/OpenLid.app"
ln -s /Applications "$STAGING/Applications"
cp LICENSE "$STAGING/LICENSE.txt"
cp Resources/DMG-README.txt "$STAGING/Read me first.txt"
hdiutil create -volname OpenLid -srcfolder "$STAGING" -format UDZO -ov -o "dist/$NAME"
hdiutil verify "dist/$NAME"
(cd dist && shasum -a 256 "$NAME" > "$NAME.sha256")
printf 'Built alpha disk image: %s/dist/%s\n' "$PWD" "$NAME"
printf 'Ad-hoc signed only. Not notarized; keep release in draft pending distribution validation.\n'
