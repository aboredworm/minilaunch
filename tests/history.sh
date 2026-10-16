#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
clang -O2 -Wall -Wextra -Wno-unused-parameter -fobjc-arc History.m Search.m tests/history.m -framework Foundation -o build/test-history
build/test-history
