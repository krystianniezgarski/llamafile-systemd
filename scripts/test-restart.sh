#!/usr/bin/env bash
set -euo pipefail
if [[ "$(id -u)" != 0 ]]; then echo 'Run with sudo.' >&2; exit 1; fi
OUT="${1:-./evidence}"
mkdir -p "$OUT"
exec > >(tee "$OUT/restart-after-kill.txt") 2>&1
systemctl is-active --quiet llamafile.service
before_pid="$(systemctl show -p MainPID --value llamafile.service)"
before_restarts="$(systemctl show -p NRestarts --value llamafile.service)"
[[ "$before_pid" -gt 1 ]]
printf 'Before: MainPID=%s NRestarts=%s\n' "$before_pid" "$before_restarts"
echo "Command: kill -KILL $before_pid"
kill -KILL "$before_pid"
passed=0
for attempt in $(seq 1 90); do
    after_pid="$(systemctl show -p MainPID --value llamafile.service)"
    after_restarts="$(systemctl show -p NRestarts --value llamafile.service)"
    if [[ "$after_pid" -gt 1 && "$after_pid" != "$before_pid" && "$after_restarts" -gt "$before_restarts" ]]; then
        if curl --fail --silent --max-time 3 http://192.168.56.10:8080/health; then
            passed=1
            printf '\nAfter: MainPID=%s NRestarts=%s\n' "$after_pid" "$after_restarts"
            break
        fi
    fi
    sleep 2
done
[[ "$passed" == 1 ]]
echo 'PASS: systemd restarted the service and HTTP API is healthy.'
