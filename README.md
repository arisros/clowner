# clowner

Clone a macOS `.app` into a second, independent copy with its own bundle
identifier — so you can run two Braves, two Slacks, two of whatever, side by
side.

An app's bundle identifier is baked into `Info.plist`, and macOS treats two
copies with the same identifier as the same app. Change the identifier and the
copy becomes a separate app to the system. Editing `Info.plist` breaks the
original code signature, so `clowner` re-signs the clone ad-hoc.

## Install

One line — no clone, no build:

```sh
curl -fsSL https://raw.githubusercontent.com/arisros/clowner/main/install.sh | sh
```

This drops the `clowner` script on your PATH (`/usr/local/bin` if writable, else
`~/.local/bin`; override with `PREFIX=…` or `BINDIR=…`). clowner is a single
Bash script that calls the macOS tools already on your Mac (`codesign`,
`PlistBuddy`) — there is no runtime to install and nothing compiled.

Or grab it by hand:

```sh
git clone https://github.com/arisros/clowner.git
ln -s "$PWD/clowner/clowner" /usr/local/bin/clowner
```

Requires macOS with the Xcode command line tools (for `codesign`; install with
`xcode-select --install`). Runs on the stock `/bin/bash` (3.2) — no newer Bash
needed. [`fzf`](https://github.com/junegunn/fzf) is optional — with it the app
picker is fuzzy-searchable, without it you get a numbered menu.

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
  type:      chromium

Name of the clone [brave_browser_2]: me_bravo
Bundle identifier [me_bravo]:
Install to [/Applications/me_bravo.app]:
Separate profile directory (- for none) [~/Library/Application Support/Clowner/me_bravo]:
```

Or skip the wizard:

```sh
clowner clone --src "/Applications/Brave Browser.app" --name me_bravo --yes
clowner list          # every app clowner can see, with its type (chromium/firefox/other)
```

### Options

| Flag | |
|---|---|
| `--src <path>` | source `.app` bundle |
| `--name <name>` | name of the clone, without `.app` |
| `--id <bundle-id>` | identifier for the clone (default: the name) |
| `--dest <path>` | where to write it (default: `/Applications/<name>.app`) |
| `--profile <path>` | isolation directory for the clone's instance |
| `--args "<flags>"` | launch flags to run the clone as its own instance (any app) |
| `--no-profile` | clone bare; share the original's data |
| `--icon <file>` | give the clone a different icon (`.icns`, or any square image) |
| `--keep-updater` | keep the Sparkle/Keystone auto-update keys |
| `--force` | overwrite an existing destination |
| `--yes` | skip the confirmation prompt |

## Not just browsers

The core — copy, re-identify, re-sign — works on **any** `.app`. Browsers are
just the case that needs one extra thing: a flag so a second copy opens its own
window instead of handing off to the running one. There are three shapes:

- **Ordinary apps** (an editor, a utility) clone **bare** and run alongside the
  original with no wrapper at all:

  ```sh
  clowner clone --src "/Applications/Some App.app" --name someapp_2 --no-profile
  ```

- **Browsers** are detected automatically and get the right isolation flags —
  Chromium apps `--user-data-dir=<profile>`, Firefox/Gecko apps
  `-no-remote --profile <profile>`. Nothing to pass.

- **Anything else that refuses to run twice** (its own single-instance lock):
  give it the flags yourself. `--args` is generic and works for any app:

  ```sh
  clowner clone --src "/Applications/Foo.app" --name foo2 --args "--its-own-flag=$HOME/foo2"
  ```

## What it does

1. Copies the bundle with `cp -a`.
2. Rewrites `CFBundleIdentifier` in every `Info.plist` inside the bundle whose
   identifier starts with the original's — the app itself and its helpers
   (`…helper`, `…helper.renderer`, and friends), leaving unrelated nested
   bundles alone.
3. Strips the auto-update keys (`KSProductID`, `SUFeedURL`, …) so the clone
   does not fight the original's updater.
4. If the clone needs to run as its own instance, replaces `Contents/MacOS/<exe>`
   with a two-line wrapper that execs the real binary with isolation flags.
   The flags are generic — pass any with `--args "..."` — and filled in
   automatically for known families (Chromium: `--user-data-dir`, Firefox:
   `-no-remote --profile`).
5. Clears quarantine attributes and re-signs with `codesign --force --deep --sign -`.

## Changing the icon

Clones share the original's icon, which makes them hard to tell apart. Pass
`--icon` to give a clone its own:

```sh
clowner clone --src "/Applications/Brave Browser.app" --name me_bravo --icon ~/bravo.png
```

A `.icns` is used as-is; any other image (PNG, JPG, ...) is converted to a
multi-resolution `.icns` — use a **square** image (1024×1024 is ideal). Because
the icon lives inside the signed bundle, clowner swaps it *before* re-signing,
so the clone stays valid. macOS caches icons aggressively; if the old one
lingers, `touch` the app or relaunch Finder/Dock (`killall Finder Dock`).

The wizard (run `clowner` with no arguments) offers an icon picker: it lists
the images in `~/Desktop`, `~/Downloads`, `~/Pictures`, and the current folder
(fzf when available, showing each image's dimensions so you can spot a square
one; a numbered menu otherwise). You can also type a path to an image kept
elsewhere, or keep the original.

## Limitations

**macOS only**

- clowner is built around the macOS app model — `.app` bundles, `Info.plist`,
  `codesign`, and `PlistBuddy`. It does nothing on Windows or Linux, where apps
  aren't signed bundles you can copy and re-identify this way. Tested on Apple
  silicon; Intel Macs use the same tools and should behave the same.

**What can't be cloned**

- **App Store apps and apps under `/System`** (Safari, Mail, Messages, …). Their
  signatures can't be reproduced ad-hoc, so the copies refuse to launch.
- Apps that hardcode their bundle identifier for **licensing or activation** may
  deactivate in the clone. Most apps don't; try it and see.

**Every clone**

- **Does not auto-update.** The updater keys are stripped, and an ad-hoc build
  couldn't take Sparkle/Keystone updates anyway. Re-run `clowner` after the
  original updates to refresh the clone.
- **Signed ad-hoc** — no hardened runtime, no team ID. `codesign` verifies, but
  Gatekeeper (`spctl`) marks it rejected; you launch it yourself, so this only
  matters to tooling that gates on `spctl`.
- **First launch shows a keychain password prompt** — click *Always Allow*,
  once. The clone is a new signing identity, so macOS asks before it may use the
  keychain (for a browser, Chromium's "Safe Storage" key for cookies/passwords).
  This can't be avoided: the original's entitlements are scoped to the vendor's
  Team ID, and an ad-hoc clone that *claims* them is killed at launch by the OS,
  so clowner deliberately drops them to keep the clone launchable. The clone
  therefore **cannot read the original's keychain items** — it keeps its own.

**Managed / secured machines**

- Changing the bundle identifier moves the clone **outside any policy keyed on
  the original id** — MDM rules, network/DLP filters, parental controls, or
  security tooling that allowlists, say, `com.brave.Browser` by bundle id. The
  clone is a different id, so those rules don't apply to it. Depending on the
  setup that means the clone is blocked from the network, or slips past controls
  meant to cover the browser — worth checking before relying on a clone at work.

**Shared state**

- A `--no-profile` clone shares the original's data directory and lock. For a
  single-instance app that means the two copies **can't run at the same time** —
  the second hands off to the first. Give it its own profile (`--profile` /
  `--args`) if you need them running together.
