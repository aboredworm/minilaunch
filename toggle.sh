#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
binary="$PWD/build/MiniLaunch.app/Contents/MacOS/MiniLaunch"
pattern=$(printf '%s' "$binary" | /usr/bin/sed 's/[][\\.^$*+?(){}|]/\\&/g')
pids=$(/usr/bin/pgrep -f "^${pattern}$" || true)
if [[ -n "$pids" ]]; then
    kill -TERM $pids
else
    exec "$binary"
fi
