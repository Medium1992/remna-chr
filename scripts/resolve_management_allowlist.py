#!/usr/bin/env python3
"""Split a comma-separated IPv4/CIDR/FQDN management allow-list safely."""

import ipaddress
import json
import sys


if len(sys.argv) != 3:
    raise SystemExit("usage: resolve_management_allowlist.py <allow-list> <controller-cidr>")

raw_items = [item.strip() for item in sys.argv[1].split(",") if item.strip()]
raw_items.append(sys.argv[2].strip())
ip_entries = []
domain_entries = []

for item in raw_items:
    try:
        value = str(ipaddress.IPv4Network(item, strict=False))
        if value not in ip_entries:
            ip_entries.append(value)
        continue
    except ValueError:
        pass

    if (
        not item
        or len(item) > 253
        or any(char not in "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789.-" for char in item)
    ):
        raise SystemExit(f"invalid allow-list item: {item!r}")
    domain = item.lower()
    if domain not in domain_entries:
        domain_entries.append(domain)

# RouterOS must receive literal entries first. When a FQDN resolves to an
# already-listed IP, adding the literal IP afterwards may fail as a duplicate.
print(json.dumps({"ip_entries": ip_entries, "domain_entries": domain_entries}))
