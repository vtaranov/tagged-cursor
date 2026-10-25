#!/bin/bash
# Интеграционные проверки probeCaret на эталонных полях (#011).
# Стенду нужно собственное разрешение в «Универсальном доступе» — выдаётся один раз.
set -euo pipefail
cd "$(dirname "$0")"

APP=build/CaretHarness.app
mkdir -p "$APP/Contents/MacOS"
swiftc -swift-version 5 -target "$(uname -m)-apple-macos13" \
    Sources/Core/*.swift Sources/Config.swift Sources/Accessibility.swift Sources/Caret.swift \
    Harness/*.swift -o "$APP/Contents/MacOS/CaretHarness"
cp Harness/Info.plist "$APP/Contents/Info.plist"
IDENTITY="Tagged Cursor Dev"
if security find-identity -p codesigning | grep -q "\"$IDENTITY\""; then
    codesign --force --sign "$IDENTITY" "$APP"
else
    codesign --force --sign - "$APP"
fi
exec "$APP/Contents/MacOS/CaretHarness"
