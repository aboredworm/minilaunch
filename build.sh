#!/bin/sh
set -eu
cd "$(dirname "$0")"
app=build/MiniLaunch.app
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
clang -O2 -Wall -Wextra -Wno-unused-parameter -fobjc-arc main.m History.m -framework AppKit -framework CoreText -o "$app/Contents/MacOS/MiniLaunch"
cp Info.plist "$app/Contents/Info.plist"
cp assets/NotoSansMono-ExtraCondensedBlack.ttf assets/OFL.txt "$app/Contents/Resources/"
printf 'Built %s/%s\n' "$PWD" "$app"
