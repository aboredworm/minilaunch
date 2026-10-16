#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
fixture="$root/install with spaces"
mkdir -p "$fixture/build/MiniLaunch.app/Contents/MacOS" "$fixture/styles"
cp toggle.sh demo-toggle.sh quit.sh "$fixture/"
export MINILAUNCH_SCRIPT_TEST_LOG="$root/arguments"
if "$fixture/demo-toggle.sh" > "$root/output" 2>&1; then
    echo 'FAIL: missing executable was accepted.' >&2
    exit 1
fi
binary="$fixture/build/MiniLaunch.app/Contents/MacOS/MiniLaunch"
printf '%s\n' '#!/bin/bash' 'printf "%s\n" "$@" > "$MINILAUNCH_SCRIPT_TEST_LOG"' > "$binary"
chmod +x "$binary"
for layout in development installed; do
    "$fixture/toggle.sh"
    [[ $(< "$MINILAUNCH_SCRIPT_TEST_LOG") == --toggle ]]
    "$fixture/quit.sh"
    [[ $(< "$MINILAUNCH_SCRIPT_TEST_LOG") == --quit ]]
    "$fixture/demo-toggle.sh"
    [[ $(< "$MINILAUNCH_SCRIPT_TEST_LOG") == $'--demo\n'"$fixture/styles" ]]
    "$fixture/demo-toggle.sh" --reset
    [[ $(< "$MINILAUNCH_SCRIPT_TEST_LOG") == --reset-demo ]]
    if "$fixture/demo-toggle.sh" --invalid > "$root/output" 2>&1; then
        echo 'FAIL: invalid demo argument was accepted.' >&2
        exit 1
    fi
    if [[ "$layout" == development ]]; then mv "$fixture/build/MiniLaunch.app" "$fixture/MiniLaunch.app"; fi
done
printf 'Script unit tests passed: native commands, argument validation, development/install layouts, paths with spaces.\n'
