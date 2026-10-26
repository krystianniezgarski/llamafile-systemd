#!/usr/bin/env bash
set -euo pipefail

# Run from the VM console: sudo bash scripts/install.sh [path/to/model.llamafile]
BASE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
source "$BASE_DIR/config/model.env"
if [[ "$(id -u)" != 0 ]]; then
    echo 'Run with sudo.' >&2
    exit 1
fi
for command in curl sha256sum useradd install systemctl nft python3; do
    command -v "$command" >/dev/null || { echo "Missing command: $command" >&2; exit 1; }
done
test -f /etc/nftables.conf
test -f "$BASE_DIR/config/llamafile.service"
install -d -m 0755 /opt/llamafile

SOURCE_MODEL="${1:-}"
if [[ -z "$SOURCE_MODEL" ]]; then
    SOURCE_MODEL=/opt/llamafile/model.llamafile.download
    curl --fail --location --retry 3 --output "$SOURCE_MODEL" "$MODEL_URL"
fi
printf '%s  %s\n' "$MODEL_SHA256" "$SOURCE_MODEL" | sha256sum --check --status

if ! id llamafile >/dev/null 2>&1; then
    useradd --system --user-group --no-create-home --home-dir /var/lib/llamafile --shell /usr/sbin/nologin llamafile
fi
[[ "$(id -u llamafile)" != 0 ]]
systemctl stop llamafile.service 2>/dev/null || true
if [[ "$SOURCE_MODEL" != /opt/llamafile/model.llamafile ]]; then
    install -o root -g root -m 0755 "$SOURCE_MODEL" /opt/llamafile/model.llamafile
fi
chmod 0755 /opt/llamafile/model.llamafile
install -d -o llamafile -g llamafile -m 0750 /var/lib/llamafile

# Preserve task 1's rules. Only add HTTP for Windows over host-only.
if [[ ! -e /etc/nftables.conf.before-ps2 ]]; then
    cp -p /etc/nftables.conf /etc/nftables.conf.before-ps2
fi
python3 - <<'PY'
from pathlib import Path
p = Path('/etc/nftables.conf')
text = p.read_text()
rule = '  iifname "host0" ip saddr 192.168.56.1 ip daddr 192.168.56.10 tcp dport 8080 counter accept comment "PS2 llamafile host-only"\n'
if 'PS2 llamafile host-only' not in text:
    anchor = '  iifname "host0" ip saddr 192.168.56.1 ip daddr 192.168.56.10 tcp dport 22 counter accept\n'
    if anchor not in text:
        raise SystemExit('Expected task 1 firewall rule not found; inspect /etc/nftables.conf.')
    text = text.replace(anchor, anchor + rule, 1)
p.with_name('nftables.conf.ps2-pending').write_text(text)
PY
nft --check --file /etc/nftables.conf.ps2-pending
mv /etc/nftables.conf.ps2-pending /etc/nftables.conf
systemctl enable nftables
systemctl restart nftables

install -o root -g root -m 0644 "$BASE_DIR/config/llamafile.service" /etc/systemd/system/llamafile.service
systemd-analyze verify /etc/systemd/system/llamafile.service
systemctl daemon-reload
systemctl enable --now llamafile.service
echo 'Unit installed. Waiting for the model HTTP health check...'
ready=0
for attempt in $(seq 1 90); do
    if curl --fail --silent --max-time 3 http://192.168.56.10:8080/health; then
        ready=1
        break
    fi
    sleep 2
done
if [[ "$ready" != 1 ]]; then
    journalctl -u llamafile.service -n 80 --no-pager >&2
    exit 1
fi
printf '\n'
systemctl --no-pager --full status llamafile.service
ss -tlnp '( sport = :8080 )'
echo PS2_INSTALL_DONE
