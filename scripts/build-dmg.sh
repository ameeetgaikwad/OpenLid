#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash scripts/build-app.sh
VERSION="$(/usr/libexec/PlistBuddy -c 'Print CFBundleShortVersionString' dist/OpenLid.app/Contents/Info.plist)"
ARCH="$(lipo -archs dist/OpenLid.app/Contents/MacOS/OpenLid | tr ' ' '-')"
NAME="OpenLid-${VERSION}-alpha.2-${ARCH}.dmg"
MOUNT="/Volumes/OpenLid Install"
if [[ -e "$MOUNT" ]]; then
    echo "Eject OpenLid Install before packaging again." >&2
    exit 1
fi
STAGING="$(mktemp -d "$PWD/dist/dmg-stage.XXXXXX")"
cleanup() {
    if mount | grep -Fq " on $MOUNT "; then hdiutil detach "$MOUNT" || return; fi
    rm -rf "$STAGING"
    if [[ -d "$MOUNT" ]]; then rmdir "$MOUNT"; fi
}
trap cleanup EXIT
mkdir "$STAGING/contents"
ditto dist/OpenLid.app "$STAGING/contents/OpenLid.app"
ln -s /Applications "$STAGING/contents/Applications"
mkdir "$STAGING/contents/.background"
cp Resources/installer.png "$STAGING/contents/.background/installer.png"
hdiutil create -volname "OpenLid Install" -srcfolder "$STAGING/contents" -format UDRW -ov -o "$STAGING/installer.dmg"
hdiutil attach "$STAGING/installer.dmg" -mountpoint "$MOUNT" -noautoopen
osascript scripts/layout-dmg.applescript "$MOUNT"
sync
test -f "$MOUNT/.DS_Store"
hdiutil detach "$MOUNT"
hdiutil convert "$STAGING/installer.dmg" -format UDZO -ov -o "dist/$NAME"
hdiutil verify "dist/$NAME"
(cd dist && shasum -a 256 "$NAME" > "$NAME.sha256")
printf 'Built alpha disk image: %s/dist/%s\n' "$PWD" "$NAME"
printf 'Ad-hoc signed only. Not notarized; alpha testing only.\n'
