# Lychgate Security Audit

An independent critical audit was performed on Lychgate v0.1 during development. This document summarizes findings and their resolution status.

## Methodology

The audit reviewed:
- `src/*.sh` (bash scripts)
- `src/compile-blocklist.py`
- SwiftBar plugin
- LaunchDaemon plist template
- Sample lists, allowlist mechanics

Areas evaluated: security, robustness, sensibility, exception handling, OSS-readiness.

## Resolved (in v0.1)

### C1 — stderr contamination of compiled blocklist ✅ FIXED
Python compiler's stats output (`=== Compile Stats ===`, `raw=`, `TOTAL=`) was being merged into the compiled blocklist via `2>&1`, then written as `0.0.0.0 === Compile Stats ===` lines to `/etc/hosts`. Domain validation regex now strips invalid lines as defense in depth, and stderr is logged separately.

### H1 — awk in `lychgate on` didn't validate domains ✅ FIXED
Lines that didn't look like domains were blindly written as `0.0.0.0 <line>`. The awk block now requires `/^[a-z0-9._-]+\.[a-z]{2,}$/`.

### H7 — allowlist could be neutralized by `*.com` ✅ FIXED
A user adding `*.com` to allowlist would (silently) void the entire block. `compile-blocklist.py` now requires wildcard suffixes to have at least 2 dots (`*.foo.com` OK, `*.com` rejected with warning).

### H8 — URL safety in `lists-enabled.conf` ✅ FIXED
URLs read from config are now validated against `^https://[A-Za-z0-9._/?=%&+~-]+$`. Anything outside this regex is skipped with a warning.

## Mitigated / not currently exposed

### C2 — LaunchDaemon LPE if installed naively
A LaunchDaemon that executes a script in a user-writable location runs as root, allowing any process running as the user to escalate by overwriting the script before its next run.

**Current mitigation**: The LaunchDaemon is **not auto-installed**. The template in `launchd/com.lychgate.update.plist.template` includes explicit instructions to move the daemon script to `/usr/local/sbin/` with `root:wheel:0755` ownership before installation.

**Future fix**: ship a proper installer that handles ownership correctly, or use a LaunchAgent (user-level, no root) for the download+compile step and rely on the regular `lychgate on` re-toggle for re-apply.

### C3 — osascript quoting fragility
The `do shell script "..."` heredoc interpolates paths verbatim. If `$HOME`, `$LYCHGATE_DATA`, or `$ORIGINAL_BACKUP` ever contain `'`, `$`, or newline, AppleScript string parsing breaks.

**Current mitigation**: All interpolated variables are derived from environment paths (`$HOME`, XDG dirs) which on typical macOS systems contain only safe characters. No user-input is interpolated.

**Future fix**: minimize osascript interpolation; pass values via environment variables exported before the AppleScript heredoc, or invoke a root-owned helper binary with hardcoded paths.

### C4 — no concurrent-toggle lock
Two parallel `lychgate on` invocations could write the block section twice.

**Future fix**: `flock`-based mutex around toggle operations.

### C5 — supply-chain trust for downloaded blocklists
`update-lists.sh` fetches Hagezi (and other) lists by URL without hash pinning. If the upstream repository were compromised, malicious entries could be inserted.

**Current mitigation**: The allowlist (`allowlist-critical.txt`) provides a last line of defense for the user's critical endpoints. URL safety regex (H8) blocks shell-injection via config.

**Future fix**: hash-pin downloaded lists per-source (`hagezi-light.sha256`). On mismatch, keep previous version and log a warning. Optional Sigstore/Cosign verification if Hagezi adopts signing.

## Remaining issues (tracked as GitHub issues)

### H2 — `is_active` matches substring
`grep -q "$SENTINEL_START"` matches if the sentinel string appears anywhere, including in a comment or in residue from another tool. Future: require both START and END sentinels in correct order.

### H3-H4 — no atomic rewrite of /etc/hosts
Modifications are not atomic — a crash or kill mid-operation could leave a partially modified file. Future: write to `/etc/hosts.new`, validate, `mv` atomically.

### H5 — `/usr/bin/python3` hardcode
macOS ships Python 3 as "compatibility only" and may remove it in a future release. Future: detect and fail gracefully if Python 3 isn't available.

### H6 — `monitor-blocks.sh` shows queries, not blocks
On macOS, `/etc/hosts` is consulted before mDNSResponder. Blocked queries never reach the resolver, so the log-stream approach shows queries that COULD be blocked, not queries that WERE blocked. The script is now documented as such. True observability would require dnscrypt-proxy.

## Sensibility audit — does this tool make sense?

The auditor's verdict:

> *"On a Mullvad-active machine with VPN-side DNS content blocking enabled, Lychgate is ~60% redundant. The additive value is concentrated in Apple-specific telemetry that Mullvad deliberately doesn't block (to avoid breaking macOS updates). The curated 67-domain core list is the real value-add."*

In practice:
- If you DO have Mullvad DNS Content Blocking enabled: Lychgate's main contribution is the Apple-telemetry-specific list
- If you DON'T: Lychgate is your primary DNS-level defense
- In both cases: Lychgate works without VPN connectivity, providing baseline protection during VPN reconnects, captive portal flows, and provider outages

Lychgate is not a replacement for a per-app firewall (Little Snitch) or for browser-level ad blockers (uBlock Origin). It's a layer in a layered defense.

## Performance audit

- /etc/hosts with ~50k entries: imperceptible
- ~100k entries: slight cold-lookup latency (~50ms), warms via mDNSResponder cache
- ~200k entries (Hagezi Pro): ~100-200ms cold latency on Intel Macs from 2017 era
- ~500k entries (Hagezi TIF): noticeable; recommended only on M1+ Macs

Default config (Hagezi Light + curated, ~167k) is fine on supported macOS versions.
