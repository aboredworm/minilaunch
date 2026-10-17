#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
fixture="$root/checkout with spaces"
mkdir -p "$fixture/build/MiniLaunch.app/Contents/MacOS" "$fixture/scripts"
cp scripts/toggle.sh scripts/quit.sh "$fixture/scripts/"
export MINILAUNCH_SCRIPT_TEST_LOG="$root/arguments"
if "$fixture/scripts/toggle.sh" > "$root/output" 2>&1; then
    echo 'FAIL: missing executable was accepted.' >&2
    exit 1
fi
binary="$fixture/build/MiniLaunch.app/Contents/MacOS/MiniLaunch"
printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$@" > "$MINILAUNCH_SCRIPT_TEST_LOG"' > "$binary"
chmod +x "$binary"
for layout in development installed; do
    "$fixture/scripts/toggle.sh"
    [[ $(< "$MINILAUNCH_SCRIPT_TEST_LOG") == --toggle ]]
    "$fixture/scripts/quit.sh"
    [[ $(< "$MINILAUNCH_SCRIPT_TEST_LOG") == --quit ]]
    if [[ "$layout" == development ]]; then
        mv "$fixture/build/MiniLaunch.app" "$fixture/scripts/MiniLaunch.app"
    fi
done
printf 'Script unit tests passed: native commands, development/install layouts, paths with spaces.\n'
