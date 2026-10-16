#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
clang -mmacosx-version-min=12.0 -O2 -Wall -Wextra -Wno-unused-parameter -fobjc-arc Search.m History.m tests/search.m -framework Foundation -o build/test-search
build/test-search
