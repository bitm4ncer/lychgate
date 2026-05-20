#!/usr/bin/env bash
# lychgate — DNS sinkhole toggle via /etc/hosts
#
# Usage:
#   lychgate on        # activate block (prompts for sudo)
#   lychgate off       # deactivate (restores /etc/hosts.original)
#   lychgate toggle    # invert
#   lychgate status    # show state
#   lychgate count     # number of domains in active list
#   lychgate update    # refresh remote blocklists (calls update-lists.sh)
#   lychgate test      # connectivity test of critical endpoints

set -u

# ============================================================
# XDG-compliant paths
# ============================================================
LYCHGATE_HOME="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

LYCHGATE_CONFIG="$XDG_CONFIG_HOME/lychgate"
LYCHGATE_DATA="$XDG_DATA_HOME/lychgate"
LYCHGATE_CACHE="$XDG_CACHE_HOME/lychgate"

COMPILED="$LYCHGATE_DATA/blocklist-compiled.txt"
CURATED="$LYCHGATE_DATA/lists/lychgate-curated.txt"
[ ! -f "$CURATED" ] && CURATED="$LYCHGATE_HOME/lists/lychgate-curated.txt"

HOSTS_FILE="/etc/hosts"
ORIGINAL_BACKUP="/etc/hosts.original"
SENTINEL_START="# === LYCHGATE BLOCK START ==="
SENTINEL_END="# === LYCHGATE BLOCK END ==="

CMD="${1:-status}"

# ============================================================
# Helpers
# ============================================================
get_active_list() {
  if [ -s "$COMPILED" ]; then echo "$COMPILED"; else echo "$CURATED"; fi
}

is_active() {
  grep -q "$SENTINEL_START" "$HOSTS_FILE" 2>/dev/null
}

count_domains_in_file() {
  grep -cvE '^[[:space:]]*(#|$)' "$1" 2>/dev/null | tr -d ' '
}

count_active_in_hosts() {
  awk -v s="$SENTINEL_START" -v e="$SENTINEL_END" '
    $0==s {inb=1; next}
    $0==e {inb=0; next}
    inb && /^0\.0\.0\.0/' "$HOSTS_FILE" 2>/dev/null | wc -l | tr -d ' '
}

source_label() {
  local list
  list="$(get_active_list)"
  if [ "$list" = "$COMPILED" ]; then
    echo "compiled"
  else
    echo "curated"
  fi
}

# ============================================================
# Commands
# ============================================================
cmd_status() {
  local count
  count="$(count_domains_in_file "$(get_active_list)")"
  if is_active; then
    local live
    live="$(count_active_in_hosts)"
    echo "🛡  Lychgate: ON ($live domains live in /etc/hosts)"
    if [ "$live" != "$count" ]; then
      echo "    Note: next apply would use $count domains from $(source_label) source"
    fi
  else
    echo "○  Lychgate: OFF (would block $count domains from $(source_label) source)"
  fi
}

cmd_count() {
  count_domains_in_file "$(get_active_list)"
}

cmd_on() {
  if is_active; then
    echo "Lychgate is already active."
    cmd_status
    exit 0
  fi

  local list count
  list="$(get_active_list)"
  count="$(count_domains_in_file "$list")"
  echo "Activating: $count domains from $(basename "$list")"

  local TMP
  TMP="$(mktemp)"
  {
    echo ""
    echo "$SENTINEL_START"
    echo "# Generated: $(date)"
    echo "# Source: $(basename "$list") ($count domains)"
    echo "# Managed by lychgate — https://github.com/bitm4ncer/lychgate"
    echo ""
    # H1 fix: domain regex filter — only valid-domain-shaped lines pass
    awk '
      /^[[:space:]]*#/ {next}
      /^[[:space:]]*$/ {next}
      !/^[a-z0-9._-]+\.[a-z]{2,}$/ {next}
      {
        printf "0.0.0.0\t%s\n", $0
        printf "::\t%s\n", $0
      }
    ' "$list"
    echo "$SENTINEL_END"
  } > "$TMP"

  /usr/bin/osascript <<APPLESCRIPT
do shell script "if [ ! -f '$ORIGINAL_BACKUP' ]; then cp '$HOSTS_FILE' '$ORIGINAL_BACKUP'; fi; cat '$TMP' >> '$HOSTS_FILE'; dscacheutil -flushcache; killall -HUP mDNSResponder 2>/dev/null" with administrator privileges with prompt "Lychgate: activate block ($count domains)"
APPLESCRIPT

  rm -f "$TMP"
  echo ""
  cmd_status
}

cmd_off() {
  if ! is_active; then
    echo "Lychgate is not active."
    exit 0
  fi
  echo "Deactivating..."

  if [ -f "$ORIGINAL_BACKUP" ]; then
    /usr/bin/osascript <<APPLESCRIPT
do shell script "cp '$ORIGINAL_BACKUP' '$HOSTS_FILE'; dscacheutil -flushcache; killall -HUP mDNSResponder 2>/dev/null" with administrator privileges with prompt "Lychgate: deactivate (restore /etc/hosts.original)"
APPLESCRIPT
  else
    /usr/bin/osascript <<APPLESCRIPT
do shell script "sed -i.bak '/$SENTINEL_START/,/$SENTINEL_END/d' '$HOSTS_FILE'; rm -f '${HOSTS_FILE}.bak'; dscacheutil -flushcache; killall -HUP mDNSResponder 2>/dev/null" with administrator privileges with prompt "Lychgate: deactivate (sed remove)"
APPLESCRIPT
  fi

  echo ""
  cmd_status
}

cmd_update() {
  "$LYCHGATE_HOME/src/update-lists.sh" "$@"
}

cmd_test() {
  "$LYCHGATE_HOME/src/test-connectivity.sh"
}

cmd_help() {
  cat <<EOF
Lychgate — DNS sinkhole via /etc/hosts

USAGE
  lychgate <command>

COMMANDS
  status                Show current state
  count                 Number of domains in active list
  on, enable            Activate block (prompts for sudo)
  off, disable          Deactivate, restore /etc/hosts.original
  toggle                Invert current state
  update [--apply]      Refresh remote lists; --apply reactivates if currently on
  test                  Connectivity test of critical endpoints

PATHS
  Config:  $LYCHGATE_CONFIG
  Data:    $LYCHGATE_DATA
  Cache:   $LYCHGATE_CACHE
  Repo:    $LYCHGATE_HOME

DOCS
  README:  $LYCHGATE_HOME/README.md
EOF
}

case "$CMD" in
  on|enable|start)    cmd_on    ;;
  off|disable|stop)   cmd_off   ;;
  status|state)       cmd_status ;;
  count)              cmd_count ;;
  update|refresh)     shift; cmd_update "$@" ;;
  test|check)         cmd_test  ;;
  toggle)             if is_active; then cmd_off; else cmd_on; fi ;;
  help|-h|--help)     cmd_help  ;;
  "")                 cmd_status ;;
  *)                  echo "Unknown command: $CMD"; cmd_help; exit 1 ;;
esac
