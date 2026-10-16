# MiniLaunch

A minimal native macOS app launcher written in Objective-C with AppKit. Tofi-inspired styling, fuzzy app search, and a steady block cursor. No third-party runtime libraries or background service.

## Install

Requires macOS 12 or later and the Xcode Command Line Tools. Homebrew and a full Xcode installation are not required. The app builds for the architecture of your Mac.

Install the Command Line Tools if you do not already have them, then finish the macOS installer before continuing:

```sh
xcode-select --install
```

Clone and build:

```sh
mkdir -p ~/.local/share
git clone https://github.com/aboredworm/minilaunch.git ~/.local/share/minilaunch
cd ~/.local/share/minilaunch
./build.sh
open build/MiniLaunch.app
```

The app stays in `build/MiniLaunch.app`. No `sudo`, system-wide installation, or separate font installation is needed. On first launch the results list is empty. Start typing an app name to search.

You can clone elsewhere if preferred. Adjust the shortcut path below to match. If you already cloned the repository, run `./build.sh` inside that checkout instead of cloning again.

## Keyboard shortcut

MiniLaunch does not register a global shortcut itself. Use a shortcut tool or window manager to run `toggle.sh` from your checkout. The script opens the launcher when it is closed and exits it when it is open.

For [AeroSpace](https://github.com/nikitabobko/AeroSpace), add this under your existing `[mode.main.binding]` section in `~/.config/aerospace/aerospace.toml` (or `~/.aerospace.toml`):

```toml
alt-u = 'exec-and-forget ~/.local/share/minilaunch/toggle.sh'
```

Reload the configuration:

```sh
aerospace reload-config
```

Option+U now opens and dismisses MiniLaunch. AeroSpace is optional; you can also open the app bundle directly. Keep `toggle.sh` beside `build/` in the checkout so it can find the executable.

## Use

Type to fuzzy-filter app names. Search matches characters in order, ignoring case and accents. For example, `sfr` matches Safari.

| Key or action | Effect |
| --- | --- |
| Up / Down | Move through results, scrolling past the seven visible rows |
| Enter | Open the selected app |
| Click / double-click | Select / open a result |
| Escape | Dismiss the launcher and exit |
| Ctrl+U | Clear the entire query, including text after the cursor |
| Ctrl+W | Delete the previous word, or the current text selection |

Normal typing, selection, and Backspace use native macOS editing. The query cursor is a non-blinking block. Nothing stays running after dismissal or a successful launch. Opening the bundle directly only shows it; reopening it does not toggle it closed.

### App discovery and history

Apps are read at startup from `/Applications`, `/System/Applications`, their `Utilities` folders, `/System/Library/CoreServices/Applications`, and `~/Applications`. There is no recursive indexing of arbitrary subfolders. Reopen the launcher after installing an app to refresh the list.

Results are ranked by successful opens through MiniLaunch, most-used first, with alphabetical ties. With an empty query, only previously opened apps appear. A fresh installation shows no results until you type.

Counts persist in:

```text
~/Library/Application Support/MiniLaunch/usage.json
```

Opening an already-running app also counts. Failed launches, dismissed searches, and apps opened elsewhere do not count. History stays local and is written atomically after successful launches. To reset ranking, quit MiniLaunch and delete this file. It contains app paths and launch counts, not search queries.

## Appearance

The borderless overlay dims the main display. Styling is inspired by [Tofi](https://github.com/philj56/tofi):

- Background `#282828` at 80% opacity, with text `#d4be98`.
- Inverted selection with 4-point padding around the selected name.
- `>  ` prompt, seven visible results, and 15-point spacing between rows.
- Selector positioned 40% across and 35% down the display.
- Bundled Noto Sans Mono ExtraCondensed Black at 18 points.

There are no input borders, list backgrounds, or scrollbars. The macOS menu bar is unchanged. Appearance values are currently set in `main.m`; rebuild after changing them. There is no runtime configuration file.

## Update

Dismiss MiniLaunch before rebuilding:

```sh
cd ~/.local/share/minilaunch
git pull --ff-only
./build.sh
```

The next launch uses the updated build. Usage history is stored separately and survives updates.

## Uninstall

Dismiss MiniLaunch, remove its shortcut binding, and delete the checkout. Optionally delete `~/Library/Application Support/MiniLaunch` to remove usage history. There is no login item or background service to unload.

## Development and checks

```sh
./build.sh
tests/history.sh
build/MiniLaunch.app/Contents/MacOS/MiniLaunch --test
build/MiniLaunch.app/Contents/MacOS/MiniLaunch --smoke-test
```

The history tests use temporary files and cover ranking, persistence, invalid data, overflow, and write failures. The expected write-failure test prints a warning.

The UI smoke test opens a temporary overlay in your logged-in desktop session and exits. It uses isolated history and fixture results to check focus, layout, font metrics, search, navigation, block-cursor geometry, and editing shortcuts. It does not launch apps. To save a preview of the selector without capturing the desktop:

```sh
MINILAUNCH_PREVIEW=/tmp/minilaunch-preview.png \
  build/MiniLaunch.app/Contents/MacOS/MiniLaunch --smoke-test
```

`tests/toggle.sh` checks three open/close cycles through AeroSpace, including that the overlay stays visible and active for three seconds. Run it with MiniLaunch closed, AeroSpace running, and the Option+U binding above installed. Check actual app launching interactively with Enter.

The deployment target is macOS 12. The current build and UI checks have been run on Apple Silicon with macOS 26; older systems and Intel Macs have not been verified.

## Troubleshooting

- **`clang` or SDK not found:** finish installing the Xcode Command Line Tools and retry `./build.sh`.
- **`toggle.sh` cannot find the executable:** build first and keep the script in the checkout. Use an absolute script path in your shortcut configuration.
- **Empty results:** type a query. The empty-query list only shows apps you have opened through MiniLaunch.
- **An app is missing:** check the discovery directories above. Nested app folders outside the listed directories are not searched.

## Font attribution

`assets/NotoSansMono-ExtraCondensedBlack.ttf` is bundled unmodified from [notofonts/noto-fonts](https://github.com/notofonts/noto-fonts/blob/326a408bd3657d082c9af9ebd63e9e1bed599d10/hinted/ttf/NotoSansMono/NotoSansMono-ExtraCondensedBlack.ttf). Its [SIL Open Font License](assets/OFL.txt) is copied into the app bundle. The font is registered only for the launcher process, with Fira Mono or system monospace as fallbacks.
