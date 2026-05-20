#!/usr/bin/env bash
# install.sh — Lychgate installer
#
# Idempotent. Run multiple times safely.
# Does NOT activate Lychgate — you must explicitly run `lychgate on`.

set -euo pipefail

LYCHGATE_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"
LYCHGATE_CONFIG="$XDG_CONFIG_HOME/lychgate"
LYCHGATE_DATA="$XDG_DATA_HOME/lychgate"
LYCHGATE_CACHE="$XDG_CACHE_HOME/lychgate"

cat <<EOF
┌────────────────────────────────────────────────────────────┐
│  🚪 Lychgate installer                                      │
│                                                            │
│  Repo:    $LYCHGATE_HOME
│  Config:  $LYCHGATE_CONFIG
│  Data:    $LYCHGATE_DATA
│  Cache:   $LYCHGATE_CACHE
│                                                            │
│  This will NOT activate any block — only install files.    │
└────────────────────────────────────────────────────────────┘
EOF

# ============================================================
# 1) Directories
# ============================================================
echo
echo "[1/5] Creating directories..."
mkdir -p "$LYCHGATE_CONFIG" "$LYCHGATE_DATA/lists" "$LYCHGATE_CACHE"

# ============================================================
# 2) Config templates (don't overwrite existing)
# ============================================================
echo "[2/5] Installing config templates..."

if [ ! -f "$LYCHGATE_CONFIG/lists-enabled.conf" ]; then
  cp "$LYCHGATE_HOME/src/lists-enabled.conf.example" "$LYCHGATE_CONFIG/lists-enabled.conf"
  echo "  ✓ $LYCHGATE_CONFIG/lists-enabled.conf"
else
  echo "  ⚠ $LYCHGATE_CONFIG/lists-enabled.conf already exists, kept yours"
fi

if [ ! -f "$LYCHGATE_CONFIG/allowlist-critical.txt" ]; then
  cp "$LYCHGATE_HOME/src/allowlist-critical.txt.example" "$LYCHGATE_CONFIG/allowlist-critical.txt"
  echo "  ✓ $LYCHGATE_CONFIG/allowlist-critical.txt"
else
  echo "  ⚠ $LYCHGATE_CONFIG/allowlist-critical.txt already exists, kept yours"
fi

# ============================================================
# 3) Bundled curated list → user data dir (for offline use)
# ============================================================
echo "[3/5] Seeding bundled curated list..."
cp "$LYCHGATE_HOME/lists/lychgate-curated.txt" "$LYCHGATE_DATA/lists/lychgate-curated.txt"

# ============================================================
# 4) Make scripts executable + create CLI symlink
# ============================================================
echo "[4/5] Wiring up CLI..."
chmod +x "$LYCHGATE_HOME/src/lychgate.sh" \
         "$LYCHGATE_HOME/src/update-lists.sh" \
         "$LYCHGATE_HOME/src/test-connectivity.sh" \
         "$LYCHGATE_HOME/src/compile-blocklist.py" \
         "$LYCHGATE_HOME/plugins/swiftbar/lychgate.30s.sh"

mkdir -p "$HOME/.local/bin"
ln -sf "$LYCHGATE_HOME/src/lychgate.sh" "$HOME/.local/bin/lychgate"
echo "  ✓ ~/.local/bin/lychgate → src/lychgate.sh"

# Tell user about PATH
if ! echo "$PATH" | tr ':' '\n' | grep -qx "$HOME/.local/bin"; then
  echo
  echo "  ⚠ ~/.local/bin is not in your PATH."
  echo "    Add this to your ~/.zshrc or ~/.bashrc:"
  echo "      export PATH=\"\$HOME/.local/bin:\$PATH\""
fi

# ============================================================
# 5) SwiftBar plugin (optional)
# ============================================================
echo "[5/5] SwiftBar plugin..."
SWIFTBAR_PLUGINS="$HOME/Library/Application Support/SwiftBar/Plugins"
if [ -d "/Applications/SwiftBar.app" ] || command -v swiftbar >/dev/null 2>&1; then
  mkdir -p "$SWIFTBAR_PLUGINS"
  ln -sf "$LYCHGATE_HOME/plugins/swiftbar/lychgate.30s.sh" \
         "$SWIFTBAR_PLUGINS/lychgate.30s.sh"
  echo "  ✓ SwiftBar plugin linked (restart SwiftBar to load)"
else
  echo "  ⊘ SwiftBar not detected — skipped"
  echo "    Install SwiftBar later: https://github.com/swiftbar/SwiftBar"
fi

# ============================================================
# Done
# ============================================================
cat <<EOF

──────────────────────────────────────────────────────────────
✓ Lychgate installed.

Next steps:
  1. Fetch remote blocklists:
       lychgate update

  2. Verify nothing critical breaks (run BEFORE activating):
       lychgate test

  3. Activate (you'll be prompted for sudo):
       lychgate on

  4. Check status:
       lychgate status

  5. Deactivate at any time:
       lychgate off

Optional:
  - Restart SwiftBar to get the 🛡 menubar icon
  - Edit $LYCHGATE_CONFIG/lists-enabled.conf to add more sources
  - Edit $LYCHGATE_CONFIG/allowlist-critical.txt to whitelist domains

Uninstall:
  ./uninstall.sh

Documentation:
  $LYCHGATE_HOME/README.md
EOF
