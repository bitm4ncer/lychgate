#!/usr/bin/env bash
# Lychgate SwiftBar plugin — refresh every 30s

PLUGIN_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LYCHGATE_HOME="$(cd "$PLUGIN_DIR/../.." && pwd)"
LYCHGATE_BIN="$LYCHGATE_HOME/src/lychgate.sh"
UPDATE_BIN="$LYCHGATE_HOME/src/update-lists.sh"
TEST_BIN="$LYCHGATE_HOME/src/test-connectivity.sh"
LIVE_MONITOR="$LYCHGATE_HOME/src/live-monitor.sh"
MONITOR_BLOCKS="$LYCHGATE_HOME/src/monitor-blocks.sh"

XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
LYCHGATE_CONFIG="$XDG_CONFIG_HOME/lychgate"
LYCHGATE_DATA="$XDG_DATA_HOME/lychgate"

COMPILED="$LYCHGATE_DATA/blocklist-compiled.txt"
CURATED="$LYCHGATE_HOME/lists/lychgate-curated.txt"
HOSTS_FILE="/etc/hosts"
SENTINEL_START="# === LYCHGATE BLOCK START ==="

is_active() {
  grep -q "$SENTINEL_START" "$HOSTS_FILE" 2>/dev/null
}

if [ -s "$COMPILED" ]; then
  ACTIVE_LIST="$COMPILED"
  SOURCE_LABEL="compiled"
else
  ACTIVE_LIST="$CURATED"
  SOURCE_LABEL="curated"
fi
COUNT=$(grep -vE '^[[:space:]]*(#|$)' "$ACTIVE_LIST" 2>/dev/null | wc -l | tr -d ' ')

if [ -f "$COMPILED" ]; then
  LAST_UPDATE=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M" "$COMPILED")
else
  LAST_UPDATE="(never)"
fi

# ============================================================
# Menubar icon — monochrome SF Symbol
# ============================================================
if is_active; then
  echo ":shield.fill: | templateImage=true"
  STATE_LABEL="🟢 Active"
  ACTION_LABEL="Disable Lychgate"
  ACTION_CMD="off"
else
  echo ":shield: | templateImage=true"
  STATE_LABEL="○ Inactive"
  ACTION_LABEL="Enable Lychgate"
  ACTION_CMD="on"
fi

echo "---"
echo "Lychgate: $STATE_LABEL"
echo "Blocking: $COUNT domains ($SOURCE_LABEL) | font=Menlo size=11"
echo "Last updated: $LAST_UPDATE | font=Menlo size=10"
echo "---"

echo "$ACTION_LABEL | bash='$LYCHGATE_BIN' param1=$ACTION_CMD terminal=false refresh=true"

echo "---"
echo "Block Lists"
if [ -d "$LYCHGATE_DATA/lists" ]; then
  for f in "$LYCHGATE_DATA/lists"/*.txt; do
    [ -f "$f" ] || continue
    name=$(basename "$f" .txt)
    c=$(grep -cvE '^[[:space:]]*(#|$)' "$f" 2>/dev/null || echo 0)
    echo "--$name: $c entries | font=Menlo size=11"
  done
fi
echo "--Update lists now | bash='$UPDATE_BIN' param1=--apply terminal=true refresh=true"
echo "--Edit lists-enabled.conf | bash=/usr/bin/open param1='$LYCHGATE_CONFIG/lists-enabled.conf' terminal=false"

echo "---"
echo "Live Monitor"
echo "--Open live DNS stream (in Terminal) | bash='$LIVE_MONITOR' terminal=true"
echo "--Show blocked queries (last 5 min) | bash='$MONITOR_BLOCKS' param1=5 terminal=true"
echo "--Show blocked queries (last 1 hour) | bash='$MONITOR_BLOCKS' param1=60 terminal=true"
echo "--ℹ︎ macOS redacts hostnames by default | color=#888888 size=10"

echo "---"
echo "Diagnostics"
echo "--Test connectivity | bash='$TEST_BIN' terminal=true"

echo "---"
echo "Edit configuration"
echo "--Allowlist | bash=/usr/bin/open param1='$LYCHGATE_CONFIG/allowlist-critical.txt' terminal=false"
echo "--Compiled blocklist | bash=/usr/bin/open param1='$COMPILED' terminal=false"
echo "--Open repo | bash=/usr/bin/open param1='$LYCHGATE_HOME' terminal=false"

echo "---"
echo "Refresh | refresh=true"
