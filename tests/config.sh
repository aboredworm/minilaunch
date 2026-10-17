#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
mkdir -p build
clang -mmacosx-version-min=12.0 -O2 -Wall -Wextra -fobjc-arc src/Config.m tests/config.m -framework AppKit -o build/test-config
build/test-config 2>build/config-warnings.log
XDG_CONFIG_HOME=/tmp/minilaunch-config-test build/test-config 2>>build/config-warnings.log
XDG_CONFIG_HOME=relative build/test-config 2>>build/config-warnings.log
grep -q 'invalid value' build/config-warnings.log
grep -q 'unknown setting' build/config-warnings.log
grep -q 'not installed; using system monospace' build/config-warnings.log
