# MiniLaunch

Minimal native macOS launcher written in Objective-C with AppKit. No third-party runtime libraries.

## Build and run

Requires macOS 12+ and the Xcode command-line tools.

```sh
./build.sh
open build/MiniLaunch.app
```

A borderless, screen-sized overlay dims the current main display. Styling follows `platforms/archlinux/.config/tofi/` in the dotfiles repo:

- Background `#282828` at 80% opacity and text `#d4be98`.
- Inverted selection with 4-point padding around the selected name.
- `>  ` prompt, seven visible results, and 15-point spacing between rows.
- Text positioned 40% across and 35% down the display.
- Bundled Noto Sans Mono ExtraCondensed Black at 18 points.

There are no window decorations, input borders, list backgrounds, or scrollbars. The macOS menu bar is unchanged. Arrow keys move through all results beyond the seven visible rows.

Type to fuzzy-filter app names. The query uses a steady block cursor with no blinking. Use Up/Down and Enter to launch, or double-click a result. Ctrl+U clears the entire query, including text after the cursor. Ctrl+W deletes the previous word using macOS word boundaries, or deletes the current text selection. These are editing shortcuts; there is no modal Vim mode. Normal typing, selection, and Backspace remain native. Escape quits the process. `./toggle.sh` starts the launcher when absent and terminates its process when present. Nothing runs in the background after dismissal or launching an app. Opening the bundle directly only shows it; macOS reopen events do not dismiss it.

The current AeroSpace configuration opens this bundle with Option+U:

```toml
alt-u = 'exec-and-forget ~/.local/share/minilaunch/toggle.sh'
```

Apps are read from the standard Applications directories and their Utilities folders when the launcher starts. Search matches characters in order, ignoring case and accents. Results are ranked by successful opens through MiniLaunch, most-used first, with alphabetical ties. There is no recursive app indexing.

With an empty query, only previously opened apps are shown. On a fresh history the list is empty; typing still searches all installed apps. Counts persist across restarts in `~/Library/Application Support/MiniLaunch/usage.json`. Opening an already-running app through MiniLaunch also counts. Failed launches, dismissed searches, and apps opened elsewhere do not count. History is local and written atomically after successful launches.

## Checks

```sh
tests/history.sh
build/MiniLaunch.app/Contents/MacOS/MiniLaunch --test
build/MiniLaunch.app/Contents/MacOS/MiniLaunch --smoke-test
```

History tests use temporary files to check frequency ordering, alphabetical ties, empty defaults, persistence, invalid data, overflow, and write failures. The expected write-failure check prints a warning. The smoke test uses an isolated history and fixture app list to check the borderless overlay, screen coverage, Tofi positioning, font size, keyboard focus, discovery, filtering, seven-row viewport navigation, mouse selection, empty defaults/results, block-cursor geometry, Ctrl+U/Ctrl+W editing, Unicode text, selection deletion, and Backspace. Set `MINILAUNCH_PREVIEW=/tmp/minilaunch-preview.png` when running it to save a preview of the selector without capturing the desktop. Launching a result can be checked interactively with Enter.

To check the AeroSpace toggle, press Option+U twice. The first press opens the overlay; the second dismisses it and exits the process. Run `tests/toggle.sh` with the launcher closed to check three cycles through AeroSpace, including that the first press produces an active, screen-sized window that stays visible for three seconds. This requires AeroSpace and the binding above.

## Font attribution

`assets/NotoSansMono-ExtraCondensedBlack.ttf` is bundled unmodified from [notofonts/noto-fonts](https://github.com/notofonts/noto-fonts/blob/326a408bd3657d082c9af9ebd63e9e1bed599d10/hinted/ttf/NotoSansMono/NotoSansMono-ExtraCondensedBlack.ttf). Its SIL Open Font License is included as `assets/OFL.txt` and copied into the app bundle. The font is registered only for the launcher process, with Fira Mono or system monospace as fallbacks.
