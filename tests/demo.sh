#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
root=$(mktemp -d)
runner=''
trap 'if [[ -n "$runner" ]]; then kill "$runner" 2>/dev/null || true; wait "$runner" 2>/dev/null || true; fi; rm -rf "$root"' EXIT
fixture="$root/install with spaces"
mkdir -p "$fixture/build/MiniLaunch.app/Contents/MacOS"
cp demo-toggle.sh toggle.sh "$fixture/"
cp -R styles "$fixture/"
export XDG_CACHE_HOME="$root/cache"
export MINILAUNCH_DEMO_TEST_LOG="$root/launched"
state="$XDG_CACHE_HOME/minilaunch/demo-next"
binary="$fixture/build/MiniLaunch.app/Contents/MacOS/MiniLaunch"

if "$fixture/demo-toggle.sh" > "$root/output" 2>&1; then
    echo 'FAIL: missing executable was accepted.' >&2
    exit 1
fi
[[ ! -e "$state" ]]
clang -O2 -Wall -Wextra -x c -o "$binary" - <<'C'
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
int main(int argc, char **argv) {
    if (argc != 3 || strcmp(argv[1], "--config") || access(argv[2], R_OK)) return 2;
    FILE *log = fopen(getenv("MINILAUNCH_DEMO_TEST_LOG"), "w");
    if (!log) return 3;
    fprintf(log, "%s\n", argv[2]);
    fclose(log);
    for (;;) pause();
}
C

start_style() {
    : > "$root/launched"
    "$fixture/demo-toggle.sh" > "$root/output" 2>&1 &
    runner=$!
    for ((attempt=0; attempt<100; attempt++)); do
        if grep -Fqx "$fixture/styles/$1.conf" "$root/launched"; then return; fi
        kill -0 "$runner"
        sleep 0.02
    done
    echo "FAIL: expected style $1." >&2
    exit 1
}

close_style() {
    "$fixture/$1"
    wait "$runner" 2>/dev/null || true
    runner=''
}

"$fixture/demo-toggle.sh" --reset
[[ $(< "$state") == 0 ]]
for style in default warm electric paper default; do
    start_style "$style"
    next=$(< "$state")
    close_style demo-toggle.sh
    [[ $(< "$state") == "$next" ]]
done
start_style warm
close_style toggle.sh
[[ $(< "$state") == 2 ]]
start_style electric
kill -TERM "$runner"
wait "$runner" 2>/dev/null || true
runner=''
start_style paper
close_style demo-toggle.sh

printf 'broken\n' > "$state"
start_style default
close_style demo-toggle.sh
"$fixture/demo-toggle.sh" --reset
[[ $(< "$state") == 0 ]]
printf '1\n' > "$state"
mv "$fixture/styles/warm.conf" "$root/warm.conf"
if "$fixture/demo-toggle.sh" > "$root/output" 2>&1; then
    echo 'FAIL: missing style was accepted.' >&2
    exit 1
fi
[[ $(< "$state") == 1 ]]
mv "$root/warm.conf" "$fixture/styles/warm.conf"
mv "$fixture/build/MiniLaunch.app" "$fixture/MiniLaunch.app"
"$fixture/demo-toggle.sh" --reset
start_style default
close_style demo-toggle.sh
start_style warm
close_style toggle.sh
printf 'Demo tests passed: order, wraparound, close, normal toggle, reset, corrupt state, missing files, paths with spaces, installed layout.\n'
