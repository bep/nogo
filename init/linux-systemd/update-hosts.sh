#!/usr/bin/env bash
# Refresh the nogo blacklist from a hosts file. Run as root.
#
#   update-hosts.sh [url-or-path]
set -euo pipefail

SRC="${1:-https://raw.githubusercontent.com/StevenBlack/hosts/master/hosts}"
DB=/var/lib/nogo/nogo.db

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

if [[ "$SRC" =~ ^https?:// ]]; then
    curl -sSfL -o "$tmp/hosts" "$SRC"
else
    cp "$SRC" "$tmp/hosts"
fi
chmod 755 "$tmp"
chmod 644 "$tmp/hosts"

# bbolt takes an exclusive lock on the file, so the service has to let go first.
if systemctl is-active --quiet nogo; then
    restart=yes
    systemctl stop nogo
else
    restart=no
fi

sudo -u nogo /usr/local/bin/nogo -db "$DB" -import "$tmp/hosts"

if [[ $restart == yes ]]; then
    systemctl start nogo
fi
