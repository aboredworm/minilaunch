#!/bin/sh
set -eu
cd "$(dirname "$0")"
app=build/MiniLaunch.app
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
clang -mmacosx-version-min=12.0 -O2 -Wall -Wextra -Wno-unused-parameter -fobjc-arc src/main.m src/Config.m src/History.m src/InstanceLock.m src/QueryEditor.m src/Search.m -framework AppKit -framework CoreText -o "$app/Contents/MacOS/MiniLaunch"
cp resources/Info.plist "$app/Contents/Info.plist"
printf 'Built %s/%s\n' "$PWD" "$app"
