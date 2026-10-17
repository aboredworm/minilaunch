# MiniLaunch

A native macOS app launcher with fuzzy search and [Tofi](https://github.com/philj56/tofi)-inspired styling. Better matches rank first; launch history breaks ties. Stays idle between searches for fast reopening.

## Install

Requires macOS 12+ and Xcode Command Line Tools (`xcode-select --install`).

```sh
mkdir -p ~/projects
git clone https://github.com/aboredworm/minilaunch.git ~/projects/minilaunch
cd ~/projects/minilaunch
./install.sh
open ~/.local/share/minilaunch/MiniLaunch.app
```

Source stays in the checkout. Only the app and launcher scripts are installed in `~/.local/share/minilaunch`. Quit MiniLaunch before rerunning `./install.sh` to deploy changes. `./build.sh` only builds the development copy.

## Use

Type an app name, select with Up/Down, and press Enter to launch. Escape hides it. Ctrl+U clears the query; Ctrl+W deletes the previous word.

An empty search shows previously launched apps. On first use, start typing.

Hiding or launching an app keeps MiniLaunch ready in the background and clears the query. Run `~/.local/share/minilaunch/quit.sh` to quit completely. The first opening after quitting is a cold launch; no login item is installed.

## Shortcut

Bind `~/.local/share/minilaunch/toggle.sh` to a shortcut to show or hide the launcher.

For AeroSpace, invoke the app directly under `[mode.main.binding]` and run `aerospace reload-config`:

```toml
alt-u = 'exec-and-forget exec ~/.local/share/minilaunch/MiniLaunch.app/Contents/MacOS/MiniLaunch --toggle'
ctrl-alt-shift-u = 'exec-and-forget exec ~/.local/share/minilaunch/MiniLaunch.app/Contents/MacOS/MiniLaunch --quit'
```

## Styling

Copy [`examples/config.example`](examples/config.example) to `~/.config/minilaunch/config` and edit it. Changes apply the next time you open the launcher. `$XDG_CONFIG_HOME/minilaunch/config` is used if set to an absolute path.

```ini
background-color = #282828
text-color = #d4be98
font = Menlo-Bold
font-size = 18
```

Defaults are gray and white with system monospace. Fonts must be installed on your Mac; none are bundled. The example file lists spacing, position, and selection options. Unknown settings and invalid values are ignored with a warning.

## Development

```sh
./build.sh
./tests/run.sh
```

The development app is built in `build/MiniLaunch.app`. Use `./scripts/toggle.sh` to show or hide it and `./scripts/quit.sh` to quit.

### Layout

- `src/`: Objective-C app code and headers
- `resources/`: app bundle metadata
- `examples/`: sample configuration
- `scripts/`: installed launcher helpers
- `tests/`: unit tests and shell checks

Build output, prompt history, and `.local/` scratch files are ignored. Keep recordings, demos, and personal experiments out of commits.
