#!/bin/sh
set -eu
cd "$(dirname "$0")"
app=build/MiniLaunch.app
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
clang -mmacosx-version-min=12.0 -O2 -Wall -Wextra -Wno-unused-parameter -fobjc-arc main.m History.m QueryEditor.m -framework AppKit -framework CoreText -o "$app/Contents/MacOS/MiniLaunch"
cp Info.plist "$app/Contents/Info.plist"
cp assets/NotoSansMono-ExtraCondensedBlack.ttf assets/OFL.txt "$app/Contents/Resources/"
printf 'Built %s/%s\n' "$PWD" "$app"
