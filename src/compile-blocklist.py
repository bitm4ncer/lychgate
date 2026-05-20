#!/usr/bin/env python3
"""
compile-blocklist.py — Merge multiple blocklists, subtract allowlist.

Usage:
  compile-blocklist.py <allowlist-file> <blocklist-file>... > compiled-output

Format-tolerant input:
  - "0.0.0.0 domain.com" (hosts file format)
  - "127.0.0.1 domain.com"
  - "domain.com" (pure domain)
  - Comments (# ...) and blank lines ignored

Allowlist format:
  - "domain.com" — exact match (overrides any block)
  - "*.domain.com" — wildcard, matches any subdomain of .domain.com
    SAFETY: wildcards with fewer than 2 dots in suffix are REJECTED
    (prevents disasters like *.com that would neutralize the entire block)
"""
import sys
import re
from pathlib import Path

if len(sys.argv) < 3:
    print("Usage: compile-blocklist.py <allowlist> <blocklist>...", file=sys.stderr)
    sys.exit(1)

allowlist_path = sys.argv[1]
input_paths = sys.argv[2:]

# Valid domain regex (basic safety net)
DOMAIN_RE = re.compile(r"^[a-z0-9._-]+\.[a-z]{2,}$")

# ============================================================
# Parse allowlist
# ============================================================
allow_exact = set()
allow_suffix = set()

try:
    with open(allowlist_path) as f:
        for lineno, line in enumerate(f, 1):
            line = line.strip()
            if not line or line.startswith('#'):
                continue
            line = line.lower()
            if line.startswith('*.'):
                # H7 fix: reject *.com / *.org / *.io etc — they'd void the entire block
                suffix = line[1:]  # ".foo.com"
                # Require at least 2 dots in the suffix (so ".co.uk" or ".foo.com" OK,
                # but ".com" alone REJECTED)
                if suffix.count('.') < 2:
                    print(
                        f"WARNING: allowlist line {lineno} '{line}' is too broad "
                        f"(wildcard suffix needs at least 2 dots), SKIPPING.",
                        file=sys.stderr,
                    )
                    continue
                allow_suffix.add(suffix)
                allow_exact.add(suffix[1:])  # also allow the parent domain itself
            else:
                if not DOMAIN_RE.match(line):
                    print(
                        f"WARNING: allowlist line {lineno} '{line}' not a valid domain, SKIPPING.",
                        file=sys.stderr,
                    )
                    continue
                allow_exact.add(line)
except FileNotFoundError:
    print(f"Note: allowlist '{allowlist_path}' not found, continuing without.",
          file=sys.stderr)

# ============================================================
# Read blocklists, dedupe, apply allowlist
# ============================================================
blocked = set()
per_source = {}

for inp_path in input_paths:
    source_name = Path(inp_path).stem
    count_raw = 0
    count_added = 0
    count_invalid = 0
    try:
        with open(inp_path) as f:
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                count_raw += 1
                parts = line.split()
                domain = None
                if len(parts) == 2 and parts[0] in ('0.0.0.0', '127.0.0.1', '::', '0:0:0:0:0:0:0:0'):
                    domain = parts[1].lower().rstrip('.')
                elif len(parts) == 1:
                    domain = parts[0].lower().rstrip('.')
                else:
                    continue
                if not domain:
                    continue
                # Validate
                if not DOMAIN_RE.match(domain):
                    count_invalid += 1
                    continue
                # Apply allowlist
                if domain in allow_exact:
                    continue
                if any(domain.endswith(s) for s in allow_suffix):
                    continue
                if domain not in blocked:
                    count_added += 1
                blocked.add(domain)
    except FileNotFoundError:
        print(f"Warning: '{inp_path}' not found, skipped.", file=sys.stderr)
        continue
    per_source[source_name] = (count_raw, count_added, count_invalid)

# ============================================================
# Stats to stderr
# ============================================================
print("=== Compile Stats ===", file=sys.stderr)
for src, (raw, added, invalid) in per_source.items():
    print(f"  {src:30s}  raw={raw:>7d}  unique-new={added:>7d}  invalid-skipped={invalid:>5d}",
          file=sys.stderr)
print(f"  {'TOTAL':30s}  unique={len(blocked):>7d}", file=sys.stderr)

# ============================================================
# Output: sorted, one domain per line, to stdout
# ============================================================
for d in sorted(blocked):
    print(d)
