#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
binary="$PWD/MiniLaunch.app/Contents/MacOS/MiniLaunch"
if [[ ! -x "$binary" ]]; then
    binary="$PWD/build/MiniLaunch.app/Contents/MacOS/MiniLaunch"
fi
exec "$binary" --quit
