#!/usr/bin/env python3
"""Read-only discovery for a safe Ubuntu-to-CHR replacement."""

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

address = next((item for item in addresses if item["local"] == preferred_source), addresses[0])
linux_interface = ipaddress.IPv4Interface(f"{address['local']}/{address['prefixlen']}")
gateway_in_linux_network = gateway in linux_interface.network

if gateway_in_linux_network:
    routeros_address = str(linux_interface)
    routeros_network = str(linux_interface.network.network_address)
    addressing_mode = "subnet"
else:
    # RouterOS uses the gateway as network in point-to-point VPS /32 setups.
    routeros_address = f"{address['local']}/32"
    routeros_network = str(gateway)
    addressing_mode = "point-to-point-/32"

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
    "routeros_ipv4": str(address["local"]),
    "gateway": str(gateway),
    "gateway_in_linux_network": gateway_in_linux_network,
    "routeros_address": routeros_address,
    "routeros_network": routeros_network,
    "addressing_mode": addressing_mode,
}
print(json.dumps(result, sort_keys=True))
