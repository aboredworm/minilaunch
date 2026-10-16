# MiniLaunch

A native macOS app launcher with fuzzy search and [Tofi](https://github.com/philj56/tofi)-inspired styling. Better matches rank first; launch history breaks ties. Nothing runs in the background when closed.

## Install

Requires macOS 12+ and Xcode Command Line Tools (`xcode-select --install`).

```sh
mkdir -p ~/projects
git clone https://github.com/aboredworm/minilaunch.git ~/projects/minilaunch
cd ~/projects/minilaunch
./install.sh
open ~/.local/share/minilaunch/MiniLaunch.app
```

Source stays in the checkout. Only the app, scripts, and demo styles are installed in `~/.local/share/minilaunch`. Rerun `./install.sh` to deploy changes; `./build.sh` only builds the development copy.

## Use

Type an app name, select with Up/Down, and press Enter to launch. Escape closes it. Ctrl+U clears the query; Ctrl+W deletes the previous word.

An empty search shows previously launched apps. On first use, start typing.

## Shortcut

Bind `~/.local/share/minilaunch/toggle.sh` to a shortcut to open or close the launcher.

For AeroSpace, add this under `[mode.main.binding]` and run `aerospace reload-config`:

```toml
alt-u = 'exec-and-forget ~/.local/share/minilaunch/toggle.sh'
alt-shift-u = 'exec-and-forget ~/.local/share/minilaunch/demo-toggle.sh'
```

## Styling

Copy [`config.example`](config.example) to `~/.config/minilaunch/config` and edit it. Changes apply the next time you open the launcher. `$XDG_CONFIG_HOME/minilaunch/config` is used if set to an absolute path.

```ini
background-color = #282828
text-color = #d4be98
font = Menlo-Bold
font-size = 18
```

Defaults are gray and white with system monospace. Fonts must be installed on your Mac; none are bundled. The example file lists spacing, position, and selection options. Unknown settings and invalid values are ignored with a warning.

## Demo styles

Option+Shift+U opens the next style each time: Default, Warm, Electric (cyan/pink, upper-left), then Paper (off-white, sand selection, Baskerville). Close with Escape or the same shortcut. Your normal config is unchanged.

Presets live in [`styles/`](styles). Run `./demo-toggle.sh --reset` to start again from Default.
