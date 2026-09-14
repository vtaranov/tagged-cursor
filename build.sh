#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"

APP=build/TaggedCursor.app
mkdir -p "$APP/Contents/MacOS"
swiftc -O -swift-version 5 -target arm64-apple-macos13 Sources/*.swift -o "$APP/Contents/MacOS/TaggedCursor"
cp Info.plist "$APP/Contents/Info.plist"
# Постоянная подпись сохраняет разрешение Универсального доступа между сборками.
IDENTITY="Tagged Cursor Dev"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
    codesign --force --sign "$IDENTITY" "$APP"
else
    echo "Сертификат \"$IDENTITY\" не найден, подписываю ad-hoc"
    codesign --force --sign - "$APP"
fi
echo "Built $APP"
