# clowner

Clone a macOS `.app` into a second, independent copy with its own bundle
identifier — so you can run two Braves, two Slacks, two of whatever, side by
side.

An app's bundle identifier is baked into `Info.plist`, and macOS treats two
copies with the same identifier as the same app. Change the identifier and the
copy becomes a separate app to the system. Editing `Info.plist` breaks the
original code signature, so `clowner` re-signs the clone ad-hoc.

## Install

```sh
git clone https://github.com/arisros/clowner.git
ln -s "$PWD/clowner/clowner" /usr/local/bin/clowner
```

Requires macOS with the Xcode command line tools (for `codesign`).
[`fzf`](https://github.com/junegunn/fzf) is optional — with it the picker is
fuzzy-searchable, without it you get a numbered menu.

## Use

Run it with no arguments and it walks you through it: pick the app, name the
clone, done.

```sh
clowner
```

```
clone which app? brave
> /Applications/Brave Browser.app
  /Applications/Chrome.app
  ...

  source:    /Applications/Brave Browser.app
  bundle id: com.brave.Browser
  chromium:  yes

Name of the clone [brave_browser_2]: me_bravo
Bundle identifier [me_bravo]:
Install to [/Applications/me_bravo.app]:
Separate profile directory (- for none) [~/Library/Application Support/Clowner/me_bravo]:
```

Or skip the wizard:

```sh
clowner clone --src "/Applications/Brave Browser.app" --name me_bravo --yes
clowner list          # every app clowner can see, and whether it is Chromium-based
```

### Options

| Flag | |
|---|---|
| `--src <path>` | source `.app` bundle |
| `--name <name>` | name of the clone, without `.app` |
| `--id <bundle-id>` | identifier for the clone (default: the name) |
| `--dest <path>` | where to write it (default: `/Applications/<name>.app`) |
| `--profile <path>` | run the clone with `--user-data-dir=<path>` (Chromium apps) |
| `--no-profile` | share the original's data instead |
| `--keep-updater` | keep the Sparkle/Keystone auto-update keys |
| `--force` | overwrite an existing destination |
| `--yes` | skip the confirmation prompt |

## What it does

1. Copies the bundle with `cp -a`.
2. Rewrites `CFBundleIdentifier` in every `Info.plist` inside the bundle whose
   identifier starts with the original's — the app itself and its helpers
   (`…helper`, `…helper.renderer`, and friends), leaving unrelated nested
   bundles alone.
3. Strips the auto-update keys (`KSProductID`, `SUFeedURL`, …) so the clone
   does not fight the original's updater.
4. For Chromium apps, replaces `Contents/MacOS/<exe>` with a two-line wrapper
   that execs the real binary with `--user-data-dir=<profile>`. Without this a
   second copy just hands off to the already-running instance instead of
   opening its own window, and both copies share one profile.
5. Clears quarantine attributes and re-signs with `codesign --force --deep --sign -`.

## Caveats

- The clone is signed **ad-hoc**: no hardened runtime, no original team ID.
  Anything that keys off the team ID — some keychain items, some app-specific
  entitlements — will treat the clone as a stranger.
- The clone **does not auto-update**. Re-run `clowner` after the original
  updates.
- App Store apps and apps under `/System` will not work; their signatures are
  not reproducible ad-hoc and the copies refuse to launch.
- Some apps hardcode their identifier for licensing or single-instance locks.
  Most do not care. Try it and see.
