#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
clang -O2 -Wall -Wextra -fobjc-arc tests/check-window.m -framework AppKit -framework CoreGraphics -o build/check-window
binding="${1:-alt-u}"
cycles="${2:-3}"
pattern=$(printf '%s' "$PWD/build/MiniLaunch.app/Contents/MacOS/MiniLaunch" | /usr/bin/sed 's/[][\\.^$*+?(){}|]/\\&/g')
pattern="${pattern}([[:space:]].*)?"
if pgrep -f "^${pattern}$" >/dev/null; then
    echo 'Dismiss MiniLaunch before running the toggle test.' >&2
    exit 1
fi
for ((cycle=1; cycle<=cycles; cycle++)); do
    aerospace trigger-binding "$binding" --mode main
    pid=''
    for ((attempt=0; attempt<100; attempt++)); do
        pid=$(pgrep -f "^${pattern}$" || true)
        if [[ -n "$pid" ]] && build/check-window "$pid" 2>/dev/null; then break; fi
        sleep 0.1
    done
    [[ -n "$pid" ]]
    build/check-window "$pid"
    sleep 3
    build/check-window "$pid"
    printf 'Cycle %s: first press opened an active overlay that stayed visible.\n' "$cycle"
    aerospace trigger-binding "$binding" --mode main
    for ((attempt=0; attempt<100; attempt++)); do
        if ! pgrep -f "^${pattern}$" >/dev/null; then break; fi
        sleep 0.1
    done
    if pgrep -f "^${pattern}$" >/dev/null; then
        echo 'FAIL: second press did not exit the launcher.' >&2
        exit 1
    fi
    printf 'Cycle %s: second press exited the launcher.\n' "$cycle"
    sleep 0.3
done
