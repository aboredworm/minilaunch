#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
styles=(default warm electric paper)
binary="$PWD/MiniLaunch.app/Contents/MacOS/MiniLaunch"
if [[ ! -x "$binary" ]]; then
    binary="$PWD/build/MiniLaunch.app/Contents/MacOS/MiniLaunch"
fi
if [[ "${XDG_CACHE_HOME:-}" == /* ]]; then
    cache="$XDG_CACHE_HOME/minilaunch"
else
    cache="$HOME/Library/Caches/MiniLaunch"
fi
state="$cache/demo-next"
if [[ $# -gt 0 ]]; then
    if [[ $# -eq 1 && "$1" == --reset ]]; then
        mkdir -p "$cache"
        printf '0\n' > "$state"
        exit 0
    fi
    echo 'Usage: demo-toggle.sh [--reset]' >&2
    exit 2
fi
pattern=$(printf '%s' "$binary" | /usr/bin/sed 's/[][\\.^$*+?(){}|]/\\&/g')
pids=$(/usr/bin/pgrep -f "^${pattern}([[:space:]]|$)" || true)
if [[ -n "$pids" ]]; then
    kill -TERM $pids
    exit 0
fi
if [[ ! -x "$binary" ]]; then
    echo 'Build MiniLaunch with ./build.sh first.' >&2
    exit 1
fi
index=0
if [[ -f "$state" ]]; then
    read -r index < "$state" || index=0
fi
case "$index" in
    0|1|2|3) ;;
    *) index=0 ;;
esac
style="$PWD/styles/${styles[index]}.conf"
if [[ ! -r "$style" ]]; then
    printf 'Missing demo style: %s\n' "$style" >&2
    exit 1
fi
mkdir -p "$cache"
temporary=$(mktemp "$state.XXXXXX")
printf '%s\n' "$(((index + 1) % ${#styles[@]}))" > "$temporary"
mv "$temporary" "$state"
printf 'MiniLaunch demo: %s\n' "${styles[index]}"
exec "$binary" --config "$style"
