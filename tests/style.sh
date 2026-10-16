#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./build.sh
binary="$PWD/build/MiniLaunch.app/Contents/MacOS/MiniLaunch"
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT

"$binary" --smoke-test
"$binary" --smoke-test --config config.example
"$binary" --smoke-test --config "$root/missing"

printf '%s\n' \
    'font = Menlo-Bold' 'font-size = 24' \
    'background-color = #112233' 'text-color = #abcdef' \
    'selection-background = #445566' 'selection-color = #fedcba' \
    'background-opacity = 0.65' 'padding = 6' 'result-spacing = 9' \
    'visible-rows = 3' 'x-position = 20' 'y-position = 70' > "$root/custom"
"$binary" --smoke-test --config "$root/custom"

printf '%s\n' 'font-size = 8' 'visible-rows = 1' 'padding = 0' \
    'result-spacing = 0' 'x-position = 100' 'y-position = 100' > "$root/small"
"$binary" --smoke-test --config "$root/small"

printf '%s\n' 'font-size = 72' 'visible-rows = 30' 'padding = 32' \
    'result-spacing = 100' 'x-position = 100' 'y-position = 0' > "$root/large"
"$binary" --smoke-test --config "$root/large"

if find build/MiniLaunch.app -type f | grep -E '\.(ttf|otf)$'; then
    echo 'FAIL: app bundle contains a font.' >&2
    exit 1
fi
printf 'Style integration tests passed.\n'
