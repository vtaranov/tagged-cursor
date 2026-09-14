#!/bin/bash
# Сборка, установка в /Applications и перезапуск.
set -euo pipefail
cd "$(dirname "$0")"

./build.sh
pkill -x TaggedCursor 2>/dev/null && sleep 0.5 || true
ditto build/TaggedCursor.app /Applications/TaggedCursor.app
open /Applications/TaggedCursor.app
echo "Installed /Applications/TaggedCursor.app $(defaults read "$PWD/Info.plist" CFBundleShortVersionString)"
