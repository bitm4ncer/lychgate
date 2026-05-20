#!/usr/bin/env bash
# uninstall.sh — Remove Lychgate from this system.
#
# Steps:
#   1. Disable any active block (restore /etc/hosts)
#   2. Remove CLI symlink
#   3. Remove SwiftBar plugin symlink
#   4. Optionally wipe config + data + cache dirs

set -u

LYCHGATE_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
LYCHGATE_CONFIG="$XDG_CONFIG_HOME/lychgate"
LYCHGATE_DATA="$XDG_DATA_HOME/lychgate"
LYCHGATE_CACHE="$XDG_CACHE_HOME/lychgate"

cat <<EOF
┌──────────────────────────────────────────────────────────┐
│  🚪 Lychgate uninstaller                                  │
└──────────────────────────────────────────────────────────┘
EOF

# 1) Disable block
if [ -x "$LYCHGATE_HOME/src/lychgate.sh" ]; then
  echo
  echo "[1/4] Disabling any active block..."
  "$LYCHGATE_HOME/src/lychgate.sh" off || true
fi

# 2) Remove CLI symlink
echo "[2/4] Removing CLI symlink..."
rm -f "$HOME/.local/bin/lychgate"

# 3) Remove SwiftBar plugin
echo "[3/4] Removing SwiftBar plugin..."
rm -f "$HOME/Library/Application Support/SwiftBar/Plugins/lychgate.30s.sh"

# 4) Optional: wipe config + data
echo
read -r -p "[4/4] Also remove $LYCHGATE_CONFIG, $LYCHGATE_DATA, $LYCHGATE_CACHE? [y/N] " ans
case "$ans" in
  y|Y|yes)
    rm -rf "$LYCHGATE_CONFIG" "$LYCHGATE_DATA" "$LYCHGATE_CACHE"
    echo "  ✓ Removed"
    ;;
  *)
    echo "  ⊘ Kept (you can manually delete later)"
    ;;
esac

cat <<EOF

✓ Lychgate uninstalled.

The repo at $LYCHGATE_HOME was not deleted — you can remove it manually:
  rm -rf $LYCHGATE_HOME
EOF
