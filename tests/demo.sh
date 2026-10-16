#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
clang -mmacosx-version-min=12.0 -O2 -Wall -Wextra -fobjc-arc Demo.m tests/demo.m -framework Foundation -o build/test-demo
build/test-demo
XDG_CACHE_HOME=/tmp/minilaunch-demo-test build/test-demo
XDG_CACHE_HOME=relative build/test-demo
