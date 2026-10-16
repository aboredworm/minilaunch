#!/bin/sh
set -eu
cd "$(dirname "$0")"
app=build/MiniLaunch.app
mkdir -p "$app/Contents/MacOS"
clang -O2 -Wall -Wextra -Wno-unused-parameter -fobjc-arc main.m -framework AppKit -o "$app/Contents/MacOS/MiniLaunch"
cp Info.plist "$app/Contents/Info.plist"
printf 'Built %s/%s\n' "$PWD" "$app"
