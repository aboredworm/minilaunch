#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")"
destination="$HOME/.local/share/minilaunch"
if [[ $# -ne 0 ]]; then
    echo 'Usage: install.sh' >&2
    exit 2
fi
if [[ -e "$destination/.git" ]]; then
    echo 'Move the source checkout out of ~/.local/share/minilaunch before installing.' >&2
    exit 1
fi
pattern=$(printf '%s' "$destination/MiniLaunch.app/Contents/MacOS/MiniLaunch" | /usr/bin/sed 's/[][\\.^$*+?(){}|]/\\&/g')
if /usr/bin/pgrep -f "^${pattern}([[:space:]]|$)" >/dev/null; then
    echo 'Quit the installed MiniLaunch with ~/.local/share/minilaunch/quit.sh before reinstalling.' >&2
    exit 1
fi
./build.sh
mkdir -p "$destination"
staging=$(mktemp -d "$destination/.install.XXXXXX")
cleanup() {
    if [[ -e "$staging/previous.app" && ! -e "$destination/MiniLaunch.app" ]]; then
        mv "$staging/previous.app" "$destination/MiniLaunch.app"
    fi
    rm -rf "$staging"
}
trap cleanup EXIT
/usr/bin/ditto build/MiniLaunch.app "$staging/MiniLaunch.app"
cp toggle.sh demo-toggle.sh quit.sh "$staging/"
mkdir "$staging/styles"
cp styles/*.conf "$staging/styles/"
if [[ -e "$destination/MiniLaunch.app" ]]; then
    mv "$destination/MiniLaunch.app" "$staging/previous.app"
fi
mv "$staging/MiniLaunch.app" "$destination/MiniLaunch.app"
/usr/bin/install -m 755 "$staging/toggle.sh" "$staging/demo-toggle.sh" "$staging/quit.sh" "$destination/"
mkdir -p "$destination/styles"
cp "$staging/styles/"*.conf "$destination/styles/"
printf 'Installed MiniLaunch in %s\n' "$destination"
