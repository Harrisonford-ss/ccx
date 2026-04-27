#!/usr/bin/env bash
# ccx installer — downloads ccx into ~/.local/bin and makes it executable.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Harrisonford-ss/ccx/main/install.sh | bash
#
# Or with a specific ref / branch:
#   CCX_REF=v0.1.0 curl -fsSL .../install.sh | bash

set -euo pipefail

REPO="${CCX_REPO:-Harrisonford-ss/ccx}"
REF="${CCX_REF:-main}"
DEST="${CCX_DEST:-$HOME/.local/bin/ccx}"
URL="https://raw.githubusercontent.com/${REPO}/${REF}/ccx"

if ! command -v python3 >/dev/null 2>&1; then
  echo "ccx: python3 is required but not found" >&2
  exit 1
fi

PYV=$(python3 -c 'import sys; print("%d.%d" % sys.version_info[:2])')
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 9) else 1)'; then
  echo "ccx: python ${PYV} too old; need >= 3.9" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"

if command -v curl >/dev/null 2>&1; then
  curl -fsSL "$URL" -o "$DEST"
elif command -v wget >/dev/null 2>&1; then
  wget -qO "$DEST" "$URL"
else
  echo "ccx: need curl or wget" >&2
  exit 1
fi

chmod +x "$DEST"

echo "ccx installed to $DEST"

case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *)
    echo
    echo "warning: $HOME/.local/bin is not on \$PATH"
    echo "add this to ~/.bashrc or ~/.zshrc:"
    echo '  export PATH="$HOME/.local/bin:$PATH"'
    ;;
esac

echo
echo "try:  ccx --help"
