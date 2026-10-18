# Source releases

## Prepare

1. Update `CHANGELOG.md` and `CFBundleShortVersionString` in `resources/Info.plist`.
2. Run `./tests/run.sh` and commit the release changes.
3. Create an annotated tag and package its tracked files:

   ```sh
   git tag -a v0.1 -m "MiniLaunch v0.1"
   ./scripts/release-source.sh v0.1
   ```

The script produces `build/releases/minilaunch-0.1.tar.gz` and its SHA-256 checksum file. It archives the tag, so build output, demos, and local files are excluded. Repeated runs for the same tag produce the same bytes.

## Publish

Publishing changes GitHub. Run these commands only when the release is ready:

```sh
git push origin main
git push origin v0.1
gh release create v0.1 \
  build/releases/minilaunch-0.1.tar.gz \
  build/releases/minilaunch-0.1.tar.gz.sha256 \
  --verify-tag --title "MiniLaunch v0.1" --notes-file CHANGELOG.md
```

The first release can use the full changelog as its release notes. For later releases, use only the relevant version's notes.

## Update the tap

In `aboredworm/tap`, update `Formula/minilaunch.rb` to use the uploaded source asset and its SHA-256 checksum:

```ruby
url "https://github.com/aboredworm/minilaunch/releases/download/v0.1/minilaunch-0.1.tar.gz"
sha256 "<checksum from minilaunch-0.1.tar.gz.sha256>"
```

Use the uploaded asset's checksum, not GitHub's automatically generated source archive. Keep `head` for development installations.

After the release is available, verify the download before pushing the tap:

```sh
brew fetch --force aboredworm/tap/minilaunch
brew install --build-from-source aboredworm/tap/minilaunch
brew test aboredworm/tap/minilaunch
brew style aboredworm/tap/minilaunch
brew audit --strict aboredworm/tap/minilaunch
```

Quit any running MiniLaunch before replacing an existing installation. Commit and push the tap only after the asset is published and checks pass. Users can then run `brew install aboredworm/tap/minilaunch`.
