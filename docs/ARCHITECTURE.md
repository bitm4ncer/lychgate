# Lychgate Architecture

## Overview

Lychgate is intentionally minimal — most of the heavy lifting is done by macOS's existing DNS resolver and the curated blocklists. There's no daemon, no kernel module, no Network Extension.

```
┌──────────────────────────────────────────────────────────┐
│  USER SPACE (no daemon, no background process)            │
├──────────────────────────────────────────────────────────┤
│                                                            │
│   lychgate.sh ──► osascript ──► sudo cp / sudo cat ──┐    │
│   (CLI toggle)                                       │    │
│                                                      ▼    │
│                                              ┌──────────┐ │
│                                              │/etc/hosts│ │
│                                              └──────────┘ │
│                                                      ▲    │
│   update-lists.sh ──► curl ──► compile-blocklist.py ─┘    │
│   (refresh remote)                                        │
│                                                            │
│   SwiftBar plugin ──► reads /etc/hosts sentinel ──► UI    │
│                                                            │
└──────────────────────────────────────────────────────────┘
                              │
                              ▼
        ┌──────────────────────────────────────────┐
        │  macOS DNS resolver (built-in)            │
        │  - reads /etc/hosts first                │
        │  - mDNSResponder cache                   │
        │  - upstream DNS (Mullvad / ISP / DoH)    │
        └──────────────────────────────────────────┘
```

## Components

### `src/lychgate.sh`
The user-facing CLI. Commands: `on`, `off`, `toggle`, `status`, `count`, `update`, `test`.

Modifies `/etc/hosts` by appending a sentinel-delimited block of `0.0.0.0 <domain>` and `:: <domain>` lines (IPv4 + IPv6). Uses `osascript do shell script ... with administrator privileges` for the sudo elevation — single password prompt per toggle.

Backs up the original `/etc/hosts` to `/etc/hosts.original` on first activation. `off` restores from backup, providing a robust rollback.

### `src/compile-blocklist.py`
Pure Python (stdlib only). Merges multiple input files into a single deduplicated domain list. Strips comments and headers. Applies the user's allowlist (with safe wildcard handling). Output is one domain per line; stats go to stderr.

### `src/update-lists.sh`
Downloads each list named in `lists-enabled.conf`, validates URL, fetches via `curl`, runs the compiler, and writes `$XDG_DATA_HOME/lychgate/blocklist-compiled.txt`. Optionally re-applies the block if the `--apply` flag is given.

### `src/test-connectivity.sh`
DNS + TCP connectivity check against a small set of must-work endpoints (Anthropic, OCSP, App Store, GitHub, captive). Distinguishes "DNS blocked to 0.0.0.0" from "TCP unreachable" — important for diagnosing whether a blocklist captured something critical.

### `src/monitor-blocks.sh`
Best-effort observability via `log show --predicate 'process == "mDNSResponder"'`. See AUDIT.md H6 for caveats.

### `plugins/swiftbar/lychgate.30s.sh`
SwiftBar plugin. Renders a SF Symbol shield in the menubar (filled if active, outline if not) and a dropdown menu with toggle, source breakdown, diagnostics, and config-file shortcuts.

### `lists/lychgate-curated.txt`
The differentiating value-add: ~67 hand-picked Apple + Google telemetry endpoints. Bundled with the repo, copied to `$LYCHGATE_DATA/lists/` on install. Always merged into the compiled output regardless of `lists-enabled.conf`.

### `launchd/com.lychgate.update.plist.template`
Optional weekly auto-update via LaunchDaemon. Includes explicit security setup steps to avoid LPE. Not auto-installed.

## File system layout (after install)

```
~/GitHub/lychgate/                         ← repo (cloned)
├── src/*.sh, src/*.py                     executable scripts
├── lists/lychgate-curated.txt             bundled curated list
├── plugins/swiftbar/lychgate.30s.sh       SwiftBar plugin
└── launchd/...template                    LaunchDaemon template

~/.local/bin/
└── lychgate -> ~/GitHub/lychgate/src/lychgate.sh   CLI symlink

~/.config/lychgate/                        user-editable config
├── lists-enabled.conf                     which lists to use
└── allowlist-critical.txt                 whitelist of safe domains

~/.local/share/lychgate/                   runtime data
├── lists/                                 downloaded blocklists
└── blocklist-compiled.txt                 merged result

~/.cache/lychgate/                         logs
└── update.log                             update history

~/Library/Application Support/SwiftBar/Plugins/
└── lychgate.30s.sh -> ~/GitHub/lychgate/plugins/swiftbar/...

/etc/hosts                                 modified by lychgate
/etc/hosts.original                        backup, created on first activation
```

## Why XDG paths instead of `~/Library/`?

- Easier to predict: `${XDG_DATA_HOME:-$HOME/.local/share}/lychgate`
- Cross-platform-friendly if Linux/Windows support is ever added
- Familiar to developers who use other XDG-compliant tools
- macOS does not enforce `~/Library/` — XDG works fine

## What's deliberately NOT here

- No daemon. The block is purely declarative (lines in `/etc/hosts`).
- No Network Extension. No conflict with VPN clients.
- No kernel extension. No System Integrity Protection involvement.
- No telemetry. Lychgate never phones home.
- No auto-update of code (only of blocklists). Updates are user-triggered or via opt-in LaunchDaemon.
