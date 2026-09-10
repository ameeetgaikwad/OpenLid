#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
bash -n scripts/build-app.sh scripts/build-dmg.sh scripts/test.sh scripts/check.sh
plutil -lint Resources/Info.plist
bash scripts/test.sh
bash scripts/build-app.sh
codesign --verify --strict dist/OpenLid.app
printf 'All automated checks passed. Live hardware checks are separate.\n'
