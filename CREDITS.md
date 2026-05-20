# Credits

Lychgate stands on the shoulders of giants. The blocklists, tools, and research that make it useful:

## Blocklists (pulled at runtime, not bundled)

### Hagezi DNS Blocklists
- **URL**: https://github.com/hagezi/dns-blocklists
- **License**: GPL-2.0
- **What we use**: `light.txt` (general ads+trackers) and `native.apple.txt` (Apple-specific telemetry) by default. Other tiers (Multi, Pro, TIF) are optional.
- **Why**: Hagezi maintains arguably the best-curated DNS blocklists in the OSS world. They publish daily, are CDN-aware, and aggressively de-duplicate to avoid breaking legitimate services.
- **Relationship to Lychgate**: Lychgate downloads Hagezi lists at runtime (`lychgate update`) and combines them with its own curated set + your allowlist. The lists are not bundled in the Lychgate repo — they live on Hagezi's GitHub and are fetched on demand. Hagezi's GPL license therefore does not propagate to Lychgate code.

### OISD (optional, off by default)
- **URL**: https://oisd.nl
- **License**: their own (free, ToU on site)
- Could be added to `lists-enabled.conf` as an alternative source.

## Tools Lychgate uses or integrates with

### SwiftBar
- **URL**: https://github.com/swiftbar/SwiftBar
- **License**: MIT
- The menu-bar plugin host. Lychgate ships a SwiftBar plugin script that gives you a 🛡 shield icon + dropdown for toggling and diagnostics.

### macOS `osascript`, `dscacheutil`, `mDNSResponder`
- Built-in to macOS. Used for the sudo-prompt UI (`osascript`) and DNS cache flushing.

## Research / inspiration

### drduh's macOS Security and Privacy Guide
- **URL**: https://github.com/drduh/macOS-Security-and-Privacy-Guide
- The de-facto reference for macOS hardening. Many of Lychgate's allowlist entries (Apple OCSP, Software Update endpoints, App Store auth) are based on the careful "do not block" notes in this guide.

### herrbischoff's telemetry list
- **URL**: https://github.com/herrbischoff/telemetry
- Cross-OS catalog of telemetry endpoints.

### The pi-hole project
- **URL**: https://pi-hole.net
- Lychgate's conceptual ancestor: DNS sinkhole for tracker domains. Lychgate is a single-host implementation of the same idea using `/etc/hosts` instead of a DNS resolver.

### dnscrypt-proxy
- **URL**: https://github.com/DNSCrypt/dnscrypt-proxy
- The "right" technical solution if you want DNS-level filtering with full logging on macOS. Lychgate is intentionally simpler (no daemon, no resolver) at the cost of features.

## Why Lychgate exists despite all of the above

None of the existing tools combine all of:
- `/etc/hosts`-based (no NetworkExtension)
- macOS-native menubar UX (no terminal-only)
- Curated focus on Apple + Google telemetry (not generic ads)
- Free and Open Source
- Compatible with VPN clients like Mullvad

Lychgate fills that specific gap. If your needs are broader, please use the giants above instead.
