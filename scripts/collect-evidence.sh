#!/usr/bin/env bash
set -euo pipefail
if [[ "$(id -u)" != 0 ]]; then echo 'Run with sudo.' >&2; exit 1; fi
OUT="${1:-./evidence}"
mkdir -p "$OUT"
date --iso-8601=seconds > "$OUT/timestamp.txt"
uname -a > "$OUT/kernel.txt"
ip -br -4 addr > "$OUT/ip-addresses.txt"
ip -4 route > "$OUT/ip-routes.txt"
ss -tlnp > "$OUT/ss-tlnp.txt"
systemctl --no-pager --full status llamafile.service > "$OUT/systemctl-status.txt"
systemctl show llamafile.service -p User -p Group -p MainPID -p NRestarts -p MemoryCurrent -p MemoryPeak -p ActiveState -p SubState -p UnitFileState > "$OUT/systemctl-show.txt"
getent passwd llamafile > "$OUT/service-user.txt"
ps -eo pid,ppid,user:16,rss,args | grep -E '[l]lamafile|[l]lama-server' > "$OUT/processes.txt"
systemctl cat llamafile.service > "$OUT/llamafile.service.txt"
nft list ruleset > "$OUT/nftables.txt"
sha256sum /opt/llamafile/model.llamafile > "$OUT/model-sha256.txt"
journalctl -u llamafile.service -n 100 --no-pager > "$OUT/journal.txt"
echo "Evidence saved to $OUT"
