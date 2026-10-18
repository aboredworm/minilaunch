#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
for test in config history instance search scripts release; do
    "./tests/$test.sh"
done
./build.sh
build/MiniLaunch.app/Contents/MacOS/MiniLaunch --test
