#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
binary="$PWD/MiniLaunch.app/Contents/MacOS/MiniLaunch"
if [[ ! -x "$binary" ]]; then
    binary="$PWD/build/MiniLaunch.app/Contents/MacOS/MiniLaunch"
fi
pattern=$(printf '%s' "$binary" | /usr/bin/sed 's/[][\\.^$*+?(){}|]/\\&/g')
pids=$(/usr/bin/pgrep -f "^${pattern}([[:space:]]|$)" || true)
if [[ -n "$pids" ]]; then
    kill -TERM $pids
else
    exec "$binary"
fi
