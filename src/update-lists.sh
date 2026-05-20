#!/usr/bin/env bash
# update-lists.sh — Download configured blocklists, compile to single file.
#
# Usage:
#   lychgate update         # update + compile only
#   lychgate update --apply # update + compile + reactivate block if currently on
#
# Reads:  $XDG_CONFIG_HOME/lychgate/lists-enabled.conf
# Writes: $XDG_DATA_HOME/lychgate/lists/*.txt
#         $XDG_DATA_HOME/lychgate/blocklist-compiled.txt
# Logs:   $XDG_CACHE_HOME/lychgate/update.log

set -u

# Paths
LYCHGATE_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

LYCHGATE_CONFIG="$XDG_CONFIG_HOME/lychgate"
LYCHGATE_DATA="$XDG_DATA_HOME/lychgate"
LYCHGATE_CACHE="$XDG_CACHE_HOME/lychgate"
LISTS_DIR="$LYCHGATE_DATA/lists"

CONF="$LYCHGATE_CONFIG/lists-enabled.conf"
ALLOWLIST="$LYCHGATE_CONFIG/allowlist-critical.txt"
COMPILED="$LYCHGATE_DATA/blocklist-compiled.txt"
CURATED_REPO="$LYCHGATE_HOME/lists/lychgate-curated.txt"
COMPILER="$LYCHGATE_HOME/src/compile-blocklist.py"
LYCHGATE_BIN="$LYCHGATE_HOME/src/lychgate.sh"
LOG="$LYCHGATE_CACHE/update.log"

mkdir -p "$LISTS_DIR" "$LYCHGATE_CACHE"

APPLY=0
[ "${1:-}" = "--apply" ] && APPLY=1

# H8 fix: validate URLs from lists-enabled.conf — only https://, no whitespace, no shell metachars.
# Use grep -E (POSIX ERE) instead of bash's [[ =~ ]] to avoid quoting issues with & and ~.
url_is_safe() {
  local u="$1"
  if [ "$u" = "file://LOCAL" ]; then return 0; fi
  if printf '%s' "$u" | grep -qE '^https://[A-Za-z0-9._/?=%&~+-]+$'; then return 0; fi
  return 1
}

echo "=== Lychgate update — $(date) ==="
echo "=== Lychgate update — $(date) ===" >> "$LOG"

# ============================================================
# Download every configured list
# ============================================================
DOWNLOADED=()
while IFS='|' read -r name url description; do
  case "$name" in ''|\#*) continue ;; esac

  target="$LISTS_DIR/${name}.txt"

  # H8: URL validation
  if ! url_is_safe "$url"; then
    echo "  ⚠️  skipping $name: URL fails safety check ($url)"
    continue
  fi

  if [ "$url" = "file://LOCAL" ]; then
    # Local curated list — copy from repo
    if [ -f "$CURATED_REPO" ]; then
      cp "$CURATED_REPO" "$target"
      n=$(grep -cvE '^[[:space:]]*(#|$)' "$target" 2>/dev/null || echo 0)
      printf "  ✅ %-30s (local, %s entries)\n" "$name" "$n"
      DOWNLOADED+=("$target")
    fi
    continue
  fi

  echo "  ⬇️  $name"
  if curl -fsSL --max-time 30 "$url" -o "${target}.tmp"; then
    size=$(wc -c < "${target}.tmp")
    if [ "$size" -lt 50 ]; then
      echo "     too small (${size}B), skipped"
      rm -f "${target}.tmp"
      [ -f "$target" ] && DOWNLOADED+=("$target")
      continue
    fi
    mv "${target}.tmp" "$target"
    n=$(grep -cvE '^[[:space:]]*(#|$)' "$target" 2>/dev/null || echo 0)
    printf "     ✅ %s entries\n" "$n"
    DOWNLOADED+=("$target")
  else
    echo "     ❌ download failed, keeping previous version"
    rm -f "${target}.tmp"
    [ -f "$target" ] && DOWNLOADED+=("$target")
  fi
done < "$CONF"

if [ ${#DOWNLOADED[@]} -eq 0 ]; then
  echo "  ❌ No lists available. Check $CONF."
  exit 1
fi

# ============================================================
# Compile
# ============================================================
echo
echo "Compiling → $COMPILED"

# C1 fix: stderr goes to log file (NOT to compiled output)
/usr/bin/env python3 "$COMPILER" "$ALLOWLIST" "${DOWNLOADED[@]}" > "${COMPILED}.tmp" 2>> "$LOG" || {
  echo "  ❌ compile failed (see $LOG)"
  rm -f "${COMPILED}.tmp"
  exit 1
}

# Defense in depth: drop any line that isn't a valid domain
awk '/^[a-z0-9._-]+\.[a-z]{2,}$/' "${COMPILED}.tmp" > "${COMPILED}.tmp2"
mv "${COMPILED}.tmp2" "$COMPILED"
rm -f "${COMPILED}.tmp"

TOTAL=$(wc -l < "$COMPILED" | tr -d ' ')
echo "  ✅ $TOTAL unique domains"

# ============================================================
# Optional re-apply if block is active
# ============================================================
SENTINEL_START="# === LYCHGATE BLOCK START ==="
if [ "$APPLY" -eq 1 ] && grep -q "$SENTINEL_START" /etc/hosts 2>/dev/null; then
  echo
  echo "=== Block is active → reactivating with fresh list ==="
  "$LYCHGATE_BIN" off
  "$LYCHGATE_BIN" on
fi

echo
echo "Done. Log: $LOG"
