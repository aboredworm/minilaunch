#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
clang -mmacosx-version-min=12.0 -O2 -Wall -Wextra -fobjc-arc src/InstanceLock.m tests/instance.m -framework Foundation -o build/test-instance
build/test-instance
