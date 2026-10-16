# MiniLaunch

Minimal native macOS launcher written in Objective-C with AppKit. No third-party dependencies.

## Build and run

Requires macOS 12+ and the Xcode command-line tools.

```sh
./build.sh
open build/MiniLaunch.app
```

A borderless, screen-sized translucent overlay dims the current main display, with a native search box and app list centered on it. There is no window title bar or shadow. The macOS menu bar is unchanged.

Type to fuzzy-filter app names. Use Up/Down and Enter to launch, or double-click a result. Escape quits the process. `./toggle.sh` starts the launcher when absent and terminates its process when present. Nothing runs in the background after dismissal or launching an app. Opening the bundle directly only shows it; macOS reopen events do not dismiss it.

The current AeroSpace configuration opens this bundle with Option+U:

```toml
alt-u = 'exec-and-forget ~/.local/share/minilaunch/toggle.sh'
```

Apps are read from the standard Applications directories and their Utilities folders when the launcher starts. Search matches characters in order, ignoring case and accents. Results are alphabetical. There is no ranking, recursive app indexing, or custom styling yet.

## Checks

```sh
build/MiniLaunch.app/Contents/MacOS/MiniLaunch --test
build/MiniLaunch.app/Contents/MacOS/MiniLaunch --smoke-test
```

The smoke test briefly opens the UI and checks the borderless overlay, screen coverage, centered selector, keyboard focus, discovery, filtering, selection, and empty results. Launching a result can be checked interactively with Enter.

To check the AeroSpace toggle, press Option+U twice. The first press opens the overlay; the second dismisses it and exits the process. Run `tests/toggle.sh` with the launcher closed to check three cycles through AeroSpace, including that the first press produces an active, screen-sized window that stays visible for three seconds. This requires AeroSpace and the binding above.
