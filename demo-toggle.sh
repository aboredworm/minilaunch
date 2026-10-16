#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
binary="$PWD/MiniLaunch.app/Contents/MacOS/MiniLaunch"
if [[ ! -x "$binary" ]]; then
    binary="$PWD/build/MiniLaunch.app/Contents/MacOS/MiniLaunch"
fi
if [[ ! -x "$binary" ]]; then
    echo 'Build MiniLaunch with ./build.sh first.' >&2
    exit 1
fi
if [[ $# -eq 1 && "$1" == --reset ]]; then
    exec "$binary" --reset-demo
fi
if [[ $# -ne 0 ]]; then
    echo 'Usage: demo-toggle.sh [--reset]' >&2
    exit 2
fi
exec "$binary" --demo "$PWD/styles"
