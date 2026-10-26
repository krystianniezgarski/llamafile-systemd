#!/usr/bin/env python3
"""Run on the Windows host: python scripts/test-access.py CURRENT_VM_LAN_IP."""
import concurrent.futures
import ipaddress
import json
from pathlib import Path
import socket
import sys
import urllib.request

lan = str(ipaddress.IPv4Address(sys.argv[1]))
addresses = {'host-only': '192.168.56.10', 'NAT': '10.0.2.15', 'LAN': lan}
def check(item):
    label, ip = item
    try:
        with socket.create_connection((ip, 8080), timeout=3):
            reachable = True
    except OSError:
        reachable = False
    return label, {'ip': ip, 'tcp_8080_reachable': reachable}
with concurrent.futures.ThreadPoolExecutor(max_workers=3) as pool:
    result = dict(pool.map(check, addresses.items()))
opener = urllib.request.build_opener(urllib.request.ProxyHandler({}))
with opener.open('http://192.168.56.10:8080/health', timeout=10) as r:
    health = {'http_status': r.status, 'body': json.load(r)}
report = {'source': 'Windows host', 'access': result, 'health': health}
target = Path(__file__).resolve().parent.parent / 'evidence' / 'windows-access.json'
target.parent.mkdir(exist_ok=True)
target.write_text(json.dumps(report, indent=2) + '\n', encoding='utf-8')
print(json.dumps(report, indent=2))
assert result['host-only']['tcp_8080_reachable'] is True
assert result['NAT']['tcp_8080_reachable'] is False
assert result['LAN']['tcp_8080_reachable'] is False
assert health['http_status'] == 200 and health['body']['status'] == 'ok'
