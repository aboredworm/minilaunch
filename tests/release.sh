#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
root=$(mktemp -d)
trap 'rm -rf "$root"' EXIT
mkdir -p "$root/scripts"
cp scripts/release-source.sh "$root/scripts/"
cd "$root"
git init -q
git config user.name 'Release Test'
git config user.email 'release-test@example.invalid'
printf 'release contents\n' > tracked.txt
git add tracked.txt scripts/release-source.sh
git -c commit.gpgsign=false commit -qm 'Test source release'
git -c tag.gpgsign=false tag v0.1
printf 'private contents\n' > untracked.txt
./scripts/release-source.sh v0.1
cp build/releases/minilaunch-0.1.tar.gz first.tar.gz
./scripts/release-source.sh v0.1
cmp first.tar.gz build/releases/minilaunch-0.1.tar.gz
(cd build/releases && shasum -a 256 -c minilaunch-0.1.tar.gz.sha256)
tar -tzf first.tar.gz > entries.txt
grep -qx 'minilaunch-0.1/tracked.txt' entries.txt
if grep -q untracked entries.txt; then exit 1; fi
for tag in v9.9 invalid ''; do
    if ./scripts/release-source.sh "$tag" > /dev/null 2>&1; then exit 1; fi
done
printf 'Source release tests passed: tagged files, reproducible archive, checksum, invalid tags.\n'
