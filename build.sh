#!/bin/sh
set -eu
cd "$(dirname "$0")"
app=build/MiniLaunch.app
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
clang -mmacosx-version-min=12.0 -O2 -Wall -Wextra -Wno-unused-parameter -fobjc-arc main.m Config.m History.m QueryEditor.m Search.m -framework AppKit -framework CoreText -o "$app/Contents/MacOS/MiniLaunch"
cp Info.plist "$app/Contents/Info.plist"
rm -f "$app/Contents/Resources/NotoSansMono-ExtraCondensedBlack.ttf" "$app/Contents/Resources/OFL.txt"
printf 'Built %s/%s\n' "$PWD" "$app"
