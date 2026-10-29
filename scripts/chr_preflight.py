#!/usr/bin/env python3
"""Read-only discovery for a safe Ubuntu-to-CHR replacement.

usage: chr_preflight.py [<target IPv4>]
"""

import ipaddress
import json
import subprocess
import sys


def command_json(*args):
    return json.loads(subprocess.check_output(args, text=True))


def has_root_mount(device):
    if "/" in (device.get("mountpoints") or []):
        return True
    return any(has_root_mount(child) for child in device.get("children") or [])


def fail(message):
    print(json.dumps({"error": message}))
    sys.exit(1)


root_source = subprocess.check_output(
    ["findmnt", "--noheadings", "--output", "SOURCE", "/"], text=True
).strip()

block_devices = command_json(
    "lsblk", "--json", "--bytes", "--output", "NAME,PATH,TYPE,SIZE,MOUNTPOINTS"
)["blockdevices"]
root_disks = [
    disk for disk in block_devices if disk.get("type") == "disk" and has_root_mount(disk)
]
if len(root_disks) != 1:
    fail(f"expected exactly one disk containing /; found {[d.get('path') for d in root_disks]}")

target_disk = root_disks[0]
routes = command_json("ip", "--json", "--4", "route", "show", "default")
if len(routes) != 1 or not routes[0].get("dev") or not routes[0].get("gateway"):
    fail(f"expected one IPv4 default route with gateway; found {routes}")

route = routes[0]
interface = route["dev"]
gateway = ipaddress.IPv4Address(route["gateway"])
preferred_source = route.get("prefsrc") or route.get("src")

address_data = command_json("ip", "--json", "--4", "address", "show", "dev", interface)
link_data = command_json("ip", "--json", "link", "show", "dev", interface)
addresses = [
    item
    for link in address_data
    for item in link.get("addr_info", [])
    if item.get("family") == "inet" and item.get("scope") == "global"
]
if not addresses:
    fail(f"no global IPv4 address found on {interface}")

interface_mac = next(
    (link.get("address") for link in link_data if link.get("address")), None
)
if not interface_mac:
    fail(f"no MAC address found on {interface}")

# Every distinct IPv4 of the interface moves to the CHR: some providers route
# several public addresses to one port (static ones next to the DHCP lease),
# and an address left behind is unreachable after the switch.  One address
# can appear with several prefixes; the one whose network holds the gateway
# wins.
by_local = {}
for item in addresses:
    candidate = ipaddress.IPv4Interface(f"{item['local']}/{item['prefixlen']}")
    current = by_local.get(item["local"])
    if current is None or (gateway in candidate.network and gateway not in current.network):
        by_local[item["local"]] = candidate

# The primary address carries the default route and the source NAT: the
# address the deployment connects to, else the route's preferred source.
target = sys.argv[1] if len(sys.argv) > 1 else None
primary_local = next(
    (local for local in (target, preferred_source) if local in by_local), next(iter(by_local))
)
linux_interface = by_local[primary_local]
gateway_in_linux_network = gateway in linux_interface.network

if gateway_in_linux_network:
    routeros_address = str(linux_interface)
    routeros_network = str(linux_interface.network.network_address)
    addressing_mode = "subnet"
else:
    # RouterOS uses the gateway as network in point-to-point VPS /32 setups.
    routeros_address = f"{primary_local}/32"
    routeros_network = str(gateway)
    addressing_mode = "point-to-point-/32"

extra_addresses = []
for local, iface in by_local.items():
    if local == primary_local:
        continue
    if gateway in iface.network:
        extra_addresses.append({"address": str(iface), "network": str(iface.network.network_address)})
    else:
        extra_addresses.append({"address": f"{local}/32", "network": local})

result = {
    "root_filesystem_source": root_source,
    "dd_target_disk": target_disk["path"],
    "dd_target_disk_size_bytes": target_disk["size"],
    "ignored_non_root_disks": [
        {"path": disk["path"], "size_bytes": disk["size"]}
        for disk in block_devices
        if disk.get("type") == "disk" and disk["path"] != target_disk["path"]
    ],
    "linux_interface": interface,
    "linux_interface_mac": interface_mac.upper(),
    "linux_address": str(linux_interface),
    "routeros_ipv4": primary_local,
    "routeros_extra_addresses": extra_addresses,
    "gateway": str(gateway),
    "gateway_in_linux_network": gateway_in_linux_network,
    "routeros_address": routeros_address,
    "routeros_network": routeros_network,
    "addressing_mode": addressing_mode,
}
print(json.dumps(result, sort_keys=True))
