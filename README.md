# 🚪 Lychgate

> *Where tracker packets go to die.*

A lightweight, OSS, DNS-level firewall for macOS. Blocks Apple-, Google-, and ad-tracking telemetry **before** it leaves your Mac — using `/etc/hosts` and curated blocklists. No kernel extension, no Network Extension drama, no conflict with VPNs.

**Status:** v0.1 — early. Works for the author. Use at your own risk.

---

## Why

You want to know — and control — what your apps send out. Apple, Google, Spotify, Adobe, and friends bake telemetry into their products without asking. Most "firewalls" for macOS (LuLu, Little Snitch) hook into the Network Extension framework, which:

- Is invasive (system extension, kernel-adjacent)
- Conflicts with VPN clients (notably Mullvad)
- Requires constant re-permission on Ventura/Sonoma (LuLu's bug)
- Often costs money (Little Snitch is $59)

**Lychgate uses a much older, simpler technique**: edit `/etc/hosts`, point tracker domains to `0.0.0.0`. The local resolver does the rest. No daemons, no kernel modules, no NetworkExtension.

## How it compares

| | Lychgate | LuLu | Little Snitch | Mullvad DNS Block |
|---|---|---|---|---|
| OSS | ✅ MIT | ✅ GPL | ❌ Proprietary | ⚠️ Service-side |
| Cost | $0 | $0 | $59 once | bundled |
| Approach | `/etc/hosts` (DNS) | NetworkExtension (packet) | NetworkExtension (packet) | DNS at VPN-server |
| Per-app blocking | ❌ system-wide | ✅ yes | ✅ yes | ❌ system-wide |
| Hardcoded-IP blocking | ❌ | ✅ | ✅ | ✅ (when VPN on) |
| Works without VPN | ✅ always | ✅ | ✅ | ❌ VPN-dependent |
| macOS Sonoma/Ventura permission resets | n/a | 🔴 yes | ✅ no | n/a |
| Conflict with Mullvad | ✅ none | 🔴 NetworkExtension conflict | ✅ none | n/a |
| Setup complexity | low | medium | low | low |

**Bottom line**: Lychgate complements rather than replaces. Best used alongside Mullvad DNS Content Blocking + uBlock Origin in your browser. Layered defense.

## What it blocks

By default (curated list), ~67 carefully picked Apple + Google telemetry endpoints:

- Apple Spotlight Web Suggestions (sends queries to Apple + Microsoft Bing)
- Apple iAd, weather analytics, Siri telemetry (`xp.apple.com`, `iadsdk.apple.com`, `weather-data.apple.com`, `guzzoni.apple.com`)
- Apple location-services tracking (`gsp*.ls.apple.com`)
- Google Analytics, DoubleClick, Tag Manager, Crashlytics, Firebase Analytics
- Optionally adds **Hagezi DNS blocklists** (~30k–250k entries depending on tier you choose)

What's **explicitly NOT blocked** (deliberate allowlist):
- Apple OCSP (code-signing validation, blocking breaks app launch)
- Apple Software Update endpoints
- App Store (`itunes.apple.com`, `mzstatic.com`)
- WLAN reachability (`captive.apple.com`)
- iCloud sync gateway

You can edit this allowlist freely.

## Installation

```bash
git clone https://github.com/bitm4ncer/lychgate.git ~/GitHub/lychgate
cd ~/GitHub/lychgate
./install.sh
```

The installer:
- Copies config templates to `~/.config/lychgate/`
- Symlinks the CLI to `~/.local/bin/lychgate`
- Symlinks the SwiftBar plugin (if SwiftBar is installed)
- **Does NOT activate anything** until you say so

## Usage

```bash
lychgate status              # see current state
lychgate on                  # activate block (prompts for sudo)
lychgate off                 # deactivate
lychgate toggle              # invert
lychgate update              # refresh remote lists
lychgate test                # verify critical endpoints still reachable
```

GUI: install [SwiftBar](https://github.com/swiftbar/SwiftBar), and a 🛡 shield appears in your menubar with full controls.

## Adding more lists

Edit `~/.config/lychgate/lists-enabled.conf`:

```
# format: name|url|description
lychgate-curated|file://LOCAL|built-in curated Apple+Google
hagezi-light|https://raw.githubusercontent.com/hagezi/dns-blocklists/main/hosts/light.txt|~30k ads+trackers
hagezi-native-apple|https://raw.githubusercontent.com/hagezi/dns-blocklists/main/hosts/native.apple.txt|~3k Apple-specific
# hagezi-multi|https://.../hosts/multi.txt|~50k normal
# hagezi-pro|https://.../hosts/pro.txt|~100k aggressive
```

Then `lychgate update && lychgate on`.

## Whitelisting domains that should always work

Edit `~/.config/lychgate/allowlist-critical.txt`. Supports exact domain or `*.domain.com` wildcards. Entries here are removed from any blocklist before compilation.

## Auto-update (optional, advanced)

The `launchd/com.lychgate.update.plist.template` lets you run weekly updates as root. **Read the security section before installing this** — it's powerful and needs the script to be in a non-user-writable location.

## How does it actually work?

```
                  ┌─────────────┐
   App: getaddrinfo("xp.apple.com")
                  └──────┬──────┘
                         │
                         ▼
            ┌────────────────────────┐
            │  macOS resolver        │
            │  1. /etc/hosts first   │ ← Lychgate writes 0.0.0.0 here
            │  2. mDNSResponder      │
            │  3. DNS server         │
            └────────────────────────┘
                         │
                         ▼
                  returns 0.0.0.0
                         │
                         ▼
                  App fails to connect
```

The script wraps your block list with sentinel comments inside `/etc/hosts`, so toggling on/off only touches the Lychgate section:

```
##
# Host Database
##
127.0.0.1   localhost
...

# === LYCHGATE BLOCK START ===
# Generated: <timestamp>
0.0.0.0     xp.apple.com
::          xp.apple.com
...
# === LYCHGATE BLOCK END ===
```

A backup of your original `/etc/hosts` is kept at `/etc/hosts.original` and restored on `lychgate off`.

## Limitations (honest)

- **Browsers with DoH bypass it**: Chrome, Firefox, and Brave with DNS-over-HTTPS enabled query their own DNS — Lychgate's `/etc/hosts` doesn't apply. Use uBlock Origin in those browsers. Vivaldi defaults to system DNS, so Lychgate works.
- **Hardcoded IPs bypass it**: Apps that call `connect(IP, port)` directly without DNS lookup escape. Apple does this for some services. There's no DNS-level fix.
- **No per-app granularity**: Lychgate is system-wide. If you want "Spotify can stream but not call analytics", use Little Snitch.
- **Large lists (>200k) cause cold-lookup latency**: macOS `getaddrinfo` reads `/etc/hosts` linearly for each query. Default config (Hagezi Light, ~166k) is fine on 8GB+ Macs.

## Security disclaimer

Lychgate modifies `/etc/hosts` as root via `osascript` (which prompts for your password). On every block toggle, the script appends a block sentinel + entries.

**Things that can break things:**
- Manual edits to `/etc/hosts` between Lychgate's sentinel markers will be lost on next toggle
- If you delete `/etc/hosts.original`, the `off` fallback is `sed`-based removal (less robust)
- Adding `*.com` (or another short suffix) to allowlist will neutralize the whole block — protect-script catches this but be careful

**Things Lychgate does NOT do:**
- Send telemetry
- Modify anything outside `/etc/hosts`, `/etc/hosts.original`, and its own config dirs
- Phone home

The code is small (<500 LOC bash + Python) — read it.

## Audit status

Lychgate received an independent critical security audit. See [docs/AUDIT.md](docs/AUDIT.md) for findings. C1 (stderr-injection into hosts file) has been fixed; C2 (LaunchDaemon LPE) is currently mitigated by not auto-installing the LaunchDaemon; C3-C5 + H1-H8 are tracked in the issues.

## Credits

- **Hagezi DNS Blocklists** — [github.com/hagezi/dns-blocklists](https://github.com/hagezi/dns-blocklists) — the high-quality curated blocklists that make this tool valuable. Lychgate's default config pulls Hagezi Light + Native Apple. Used at runtime, not bundled.
- **SwiftBar** — [github.com/swiftbar/SwiftBar](https://github.com/swiftbar/SwiftBar) — the menu bar plugin host
- **drduh's macOS Security Guide** — for the foundational telemetry-blocking research
- **macOS-defaults.com** — for the broader macOS hardening community

## License

MIT — see [LICENSE](LICENSE).

## Contributing

PRs welcome. Especially:
- New trackers/sniffers to add to the curated list (with justification + source)
- Bug reports with `/etc/hosts` corruption scenarios
- macOS Sonoma/Sequoia compatibility testing
- Translation of UI strings (currently English/German mix in messages)

For security issues, **do not file public issues**. Email [your email here].

---

*Lychgate is not affiliated with the architectural term, the band, or any other entity sharing the name.*
