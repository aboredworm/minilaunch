# MiniLaunch

A native macOS app launcher with fuzzy search and [Tofi](https://github.com/philj56/tofi)-inspired styling. Ranks apps by how often you launch them. Nothing runs in the background when closed.

## Install

Requires macOS 12+ and Xcode Command Line Tools (`xcode-select --install`).

```sh
mkdir -p ~/.local/share
git clone https://github.com/aboredworm/minilaunch.git ~/.local/share/minilaunch
cd ~/.local/share/minilaunch
./build.sh
open build/MiniLaunch.app
```

## Use

Type an app name, select with Up/Down, and press Enter to launch. Escape closes it. Ctrl+U clears the query; Ctrl+W deletes the previous word.

An empty search shows previously launched apps. On first use, start typing.

## Shortcut

Bind `~/.local/share/minilaunch/toggle.sh` to a shortcut to open or close the launcher.

For AeroSpace, add this under `[mode.main.binding]` and run `aerospace reload-config`:

```toml
alt-u = 'exec-and-forget ~/.local/share/minilaunch/toggle.sh'
```

Bundled font: Noto Sans Mono ExtraCondensed Black, licensed under the [SIL Open Font License](assets/OFL.txt).
