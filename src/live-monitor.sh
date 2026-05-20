#!/usr/bin/env bash
# live-monitor.sh — best-effort live DNS query monitor for Lychgate
#
# Honest caveats (read please):
#   1. macOS redacts hostnames in mDNSResponder logs by default
#      ("<mask.hash: 'BBxxxx'>"). You can disable that with:
#          sudo log config --mode "private_data:on"
#      (per-session; reverts on next boot)
#   2. Lychgate's /etc/hosts blocks intercept queries BEFORE they reach
#      mDNSResponder, so true blocks are NOT logged here. This stream
#      shows DNS activity that DID reach the resolver — i.e. queries
#      that were NOT blocked at the hosts file.
#   3. For real query/block logging, use dnscrypt-proxy instead.

cat <<'EOF'

╔════════════════════════════════════════════════════════════════════╗
║  Lychgate Live Monitor — DNS activity stream                        ║
║                                                                     ║
║  ⚠ Hostnames may be redacted as "<mask.hash: ...>" by macOS.        ║
║  ⚠ This shows DNS queries that REACHED the resolver — Lychgate      ║
║    blocks happen BEFORE this point and aren't visible here.         ║
║                                                                     ║
║  To unmask hostnames (per-session):                                  ║
║      sudo log config --mode "private_data:on"                       ║
║                                                                     ║
║  Press Ctrl+C to stop.                                              ║
╚════════════════════════════════════════════════════════════════════╝

EOF

sleep 1

log stream \
  --predicate 'process == "mDNSResponder" AND (eventMessage CONTAINS "Sent" OR eventMessage CONTAINS "Received")' \
  --style compact \
  --info
