#!/usr/bin/env bash
# Install nogo as a systemd service and make it the system resolver.
# Run as root from a checkout: sudo init/linux-systemd/install.sh
#
# Layout after install:
#   /usr/local/bin/nogo          binary
#   /var/lib/nogo/nogo.db        blacklist database (owned by the nogo user)
#   nogo listens on 127.0.0.1:53 (DNS) and 127.0.0.1:8123 (control panel)
#
# DNS chain: application -> systemd-resolved (127.0.0.53, caching) -> nogo
# (127.0.0.1) -> upstream. resolved stays in front so we keep its cache and
# its /etc/resolv.conf handling; the NetworkManager drop-in is what stops
# DHCP-provided servers from being used instead of nogo.
set -euo pipefail

[[ $EUID -eq 0 ]] || { echo "run as root" >&2; exit 1; }

cd "$(dirname "$0")/../.."

id nogo &>/dev/null || useradd --system --no-create-home --home-dir /var/lib/nogo --shell /usr/sbin/nologin nogo

# Build first if needed: go build -o nogo .
BIN="${NOGO_BIN:-./nogo}"
[[ -x "$BIN" ]] || { echo "no binary at $BIN — run 'go build -o nogo .' first, or set NOGO_BIN" >&2; exit 1; }

install -m 755 "$BIN" /usr/local/bin/nogo
install -m 755 init/linux-systemd/update-hosts.sh /usr/local/bin/nogo-update-hosts
install -m 644 init/linux-systemd/nogo.service /etc/systemd/system/nogo.service

install -d -o nogo -g nogo -m 755 /var/lib/nogo

mkdir -p /etc/systemd/resolved.conf.d
cat > /etc/systemd/resolved.conf.d/50-nogo.conf <<'EOF'
# Send everything through nogo instead of the DHCP-provided servers.
[Resolve]
DNS=127.0.0.1
Domains=~.
EOF

mkdir -p /etc/NetworkManager/conf.d
cat > /etc/NetworkManager/conf.d/50-nogo-dns.conf <<'EOF'
# Global DNS overrides the per-connection (DHCP) servers, so every network
# this machine joins resolves through nogo.
[global-dns-domain-*]
servers=127.0.0.1
EOF

systemctl daemon-reload
systemctl enable nogo

if [[ ! -f /var/lib/nogo/nogo.db ]]; then
    echo "Importing initial blacklist..."
    /usr/local/bin/nogo-update-hosts
fi

systemctl restart nogo
systemctl restart systemd-resolved
systemctl reload NetworkManager

echo
resolvectl status | sed -n '/^Link/,$p'
echo "Done. Control panel: http://127.0.0.1:8123/"
