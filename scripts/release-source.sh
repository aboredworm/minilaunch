#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [[ $# -ne 1 || ! "$1" =~ ^v[0-9]+\.[0-9]+(\.[0-9]+)?$ ]]; then
    echo 'Usage: scripts/release-source.sh vVERSION' >&2
    exit 2
fi
tag="$1"
git rev-parse --verify "refs/tags/$tag" >/dev/null
name="minilaunch-${tag#v}"
mkdir -p build/releases
staging=$(mktemp -d build/releases/.source.XXXXXX)
trap 'rm -rf "$staging"' EXIT
git archive --format=tar --prefix="$name/" "refs/tags/$tag" | gzip -n > "$staging/$name.tar.gz"
(
    cd "$staging"
    shasum -a 256 "$name.tar.gz" > "$name.tar.gz.sha256"
)
mv "$staging/$name.tar.gz" "$staging/$name.tar.gz.sha256" build/releases/
printf 'Created build/releases/%s.tar.gz\n' "$name"
