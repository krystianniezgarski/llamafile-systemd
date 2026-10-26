#!/usr/bin/env python3
"""Adjust task 1's LAN allow-list after the host moves to another network."""
import ipaddress
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys

if os.geteuid() != 0 or len(sys.argv) != 3:
    raise SystemExit('Usage: sudo python3 scripts/update-lan-firewall.py WINDOWS_LAN_IP LAN_CIDR')
host = ipaddress.IPv4Address(sys.argv[1])
network = ipaddress.IPv4Network(sys.argv[2], strict=True)
if host not in network or network.prefixlen < 16:
    raise SystemExit('Host must belong to the specified LAN; use its actual subnet.')
for reserved in ('10.0.2.0/24', '192.168.56.0/24'):
    if network.overlaps(ipaddress.IPv4Network(reserved)):
        raise SystemExit('LAN overlaps with NAT or host-only.')
path = Path('/etc/nftables.conf')
text = path.read_text()
text, dropped = re.subn(r'(iifname "lan0" ip saddr )\S+( counter drop)', lambda m: m[1] + str(host) + m[2], text)
text, allowed = re.subn(r'(iifname "lan0" ip saddr )\S+( (?:tcp dport 22|icmp type echo-request))', lambda m: m[1] + str(network) + m[2], text)
if dropped != 1 or allowed != 2:
    raise SystemExit('Expected task 1 LAN rules not found; firewall unchanged.')
pending = path.with_name('nftables.conf.lan-pending')
pending.write_text(text)
pending.chmod(0o644)
subprocess.run(['nft', '--check', '--file', str(pending)], check=True)
backup = path.with_name('nftables.conf.before-lan-update')
if not backup.exists():
    shutil.copy2(path, backup)
pending.replace(path)
subprocess.run(['systemctl', 'restart', 'nftables'], check=True)
print(f'LAN rules: Windows={host}, network={network}; host-only and NAT unchanged.')
