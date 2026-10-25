#!/bin/bash
# Юнит-тесты чистой логики (Sources/Core). Swift Testing без Xcode: нужны явные
# пути к фреймворкам Command Line Tools.
set -euo pipefail
cd "$(dirname "$0")"

F=$(xcode-select -p)/Library/Developer/Frameworks
L=$(xcode-select -p)/Library/Developer/usr/lib
swift test \
    -Xswiftc -F -Xswiftc "$F" \
    -Xlinker -F -Xlinker "$F" \
    -Xlinker -rpath -Xlinker "$F" \
    -Xlinker -rpath -Xlinker "$L" "$@"
