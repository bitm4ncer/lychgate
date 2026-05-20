#!/usr/bin/env bash
# monitor-blocks.sh — Show DNS queries against Lychgate blocklist in recent history.
#
# Caveat (audit finding H6): on macOS, /etc/hosts is consulted BEFORE
# mDNSResponder. Lookups for blocked domains get resolved to 0.0.0.0
# locally and never hit mDNSResponder's log. This script therefore
# shows "DNS queries that COULD be blocked" — including those that were
# made before Lychgate became active.
#
# For real-time observability with full logging, consider
# dnscrypt-proxy with its query log.
#
# Usage:
#   monitor-blocks.sh           # default: last 5 minutes
#   monitor-blocks.sh 60        # last 60 minutes

set -u

MINUTES="${1:-5}"

LYCHGATE_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
LYCHGATE_DATA="$XDG_DATA_HOME/lychgate"
COMPILED="$LYCHGATE_DATA/blocklist-compiled.txt"
CURATED="$LYCHGATE_HOME/lists/lychgate-curated.txt"

if [ -s "$COMPILED" ]; then
  ACTIVE_LIST="$COMPILED"
else
  ACTIVE_LIST="$CURATED"
fi

if [ ! -s "$ACTIVE_LIST" ]; then
  echo "No blocklist available. Run: lychgate update"
  exit 1
fi

echo "=== Lychgate Monitor — last ${MINUTES}m ==="
echo "Source list: $(basename "$ACTIVE_LIST")"
echo "Note: shows DNS lookups for domains in blocklist; for blocked-by-Lychgate"
echo "      they returned 0.0.0.0. For pre-block queries: real resolution."
echo

# Collect blocked domains for grep alternation (max 5000 to keep grep sane)
PATTERNS=$(head -5000 "$ACTIVE_LIST" | grep -vE '^[[:space:]]*(#|$)' | sed 's/\./\\./g' | tr '\n' '|' | sed 's/|$//')

if [ -z "$PATTERNS" ]; then
  echo "Blocklist appears empty."
  exit 0
fi

# Pull mDNSResponder DNS query log lines + grep against blocklist
log show \
  --predicate 'process == "mDNSResponder"' \
  --last "${MINUTES}m" \
  --style compact 2>/dev/null \
  | grep -iE "$PATTERNS" \
  | awk '{
      for (i=1; i<=NF; i++) {
        if ($i ~ /[a-z0-9.-]+\.[a-z]{2,}/) {
          print $1, $2, "→", $i
          break
        }
      }
    }' \
  | sort -u \
  | head -100
