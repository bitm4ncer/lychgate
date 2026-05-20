#!/usr/bin/env bash
# test-connectivity.sh — Verify critical endpoints are reachable.
#
# Important for diagnosing whether the block list inadvertently
# captured something essential.

set -u

# M3 fix from audit: don't just nc-check TCP, also verify DNS resolves
# to a non-zero answer. Otherwise a 0.0.0.0-pointed entry would appear
# "reachable" if anything is listening on localhost.

CRITICAL=(
  "api.anthropic.com:443:Claude API"
  "ocsp.apple.com:443:Apple Code-Signing"
  "swcdn.apple.com:443:macOS Updates"
  "captive.apple.com:80:WLAN Reachability"
  "itunes.apple.com:443:App Store"
  "github.com:443:GitHub"
)

OK=0
FAIL=0
RESULTS=()

for entry in "${CRITICAL[@]}"; do
  IFS=':' read -r host port label <<< "$entry"

  # DNS check: does it resolve to a real IP?
  ip="$(dig +short +time=2 +tries=1 "$host" A 2>/dev/null | head -1)"
  if [ -z "$ip" ]; then
    RESULTS+=("❌ $label  ($host:$port) — DNS no answer")
    FAIL=$((FAIL+1))
    continue
  fi
  if [ "$ip" = "0.0.0.0" ]; then
    RESULTS+=("❌ $label  ($host:$port) — BLOCKED in /etc/hosts (DNS → 0.0.0.0)")
    FAIL=$((FAIL+1))
    continue
  fi

  # TCP check
  if /usr/bin/nc -z -G 3 "$host" "$port" >/dev/null 2>&1; then
    RESULTS+=("✅ $label  ($host:$port) → $ip")
    OK=$((OK+1))
  else
    RESULTS+=("⚠️  $label  ($host:$port) → $ip — DNS ok but TCP unreachable")
    FAIL=$((FAIL+1))
  fi
done

echo "=== Lychgate Connectivity Test ==="
for r in "${RESULTS[@]}"; do echo "  $r"; done
echo
echo "OK: $OK / $((OK+FAIL))"

if [ "$FAIL" -gt 0 ]; then
  echo
  echo "⚠️  $FAIL critical endpoint(s) unreachable."
  echo "If Lychgate is currently active, consider:"
  echo "  - Check ~/.config/lychgate/allowlist-critical.txt — is the failing domain listed?"
  echo "  - If not, add it (exact line or *.domain.tld wildcard)"
  echo "  - Then: lychgate update && lychgate off && lychgate on"
  echo "Emergency disable: lychgate off"
  exit 1
fi
exit 0
