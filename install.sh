#!/usr/bin/env bash
#
# clowner installer — fetches the clowner script and drops it on your PATH.
#
#   curl -fsSL https://raw.githubusercontent.com/arisros/clowner/main/install.sh | sh
#
# Override the install location with PREFIX or BINDIR:
#   curl -fsSL .../install.sh | PREFIX="$HOME/.local" sh
#   curl -fsSL .../install.sh | BINDIR="$HOME/bin" sh

set -eu

REPO="arisros/clowner"
REF="${CLOWNER_REF:-main}"
SRC="https://raw.githubusercontent.com/$REPO/$REF/clowner"

# Where to install: explicit BINDIR wins, else PREFIX/bin, else a sensible default.
if [ -n "${BINDIR:-}" ]; then
  bindir="$BINDIR"
elif [ -n "${PREFIX:-}" ]; then
  bindir="$PREFIX/bin"
elif [ -w /usr/local/bin ] 2>/dev/null || [ "$(id -u)" = "0" ]; then
  bindir="/usr/local/bin"
else
  bindir="$HOME/.local/bin"
fi

case "$(uname -s)" in
  Darwin) ;;
  *) echo "clowner is macOS only (needs codesign and PlistBuddy)." >&2; exit 1 ;;
esac
command -v codesign >/dev/null 2>&1 || {
  echo "codesign not found — install the Xcode command line tools: xcode-select --install" >&2
  exit 1
}

mkdir -p "$bindir"
dest="$bindir/clowner"

echo "Installing clowner -> $dest"
if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$SRC" -o "$dest"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$dest" "$SRC"
else
  echo "need curl or wget to download clowner" >&2
  exit 1
fi
chmod +x "$dest"

echo "Installed clowner $("$dest" --version 2>/dev/null | awk '{print $2}')"
case ":$PATH:" in
  *":$bindir:"*) ;;
  *) echo "Note: $bindir is not on your PATH. Add it:"
     echo "      echo 'export PATH=\"$bindir:\$PATH\"' >> ~/.zshrc" ;;
esac
echo "Run 'clowner' to start."
