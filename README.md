# nogo

A DNS proxy that answers `NXDOMAIN` for blacklisted domains and forwards everything else upstream. The blacklist lives in a [bbolt](https://github.com/etcd-io/bbolt) database, imported from any hosts file (e.g. [StevenBlack/hosts](https://github.com/StevenBlack/hosts)), and is managed from a small web control panel.

This is a fork of [Seth Davis' nogo](https://github.com/curia-solutions/nogo).

![Screenshot](screenshot.jpg)

## Install

```
go build -o nogo .
```

## Flags

| Flag | Default | Description |
| --- | --- | --- |
| `-db` | `nogo.db` | Database file path. |
| `-dns-addr` | `:53` | Address for the DNS proxy to listen on. |
| `-dns-net` | `udp` | `udp`, `tcp` or `udp+tcp`. |
| `-dns-proxyto` | `8.8.8.8:53,8.8.4.4:53` | Comma separated upstream resolvers, tried in order. |
| `-import` | | Hosts file to import into the blacklist. Imports and exits. |
| `-web-addr` | `:8080` | Address for the control panel/API. |
| `-web-off` | `false` | Don't serve the control panel/API. |
| `-web-password` | | Require basic auth (`admin` + this password) for the control panel/API. |

The database is locked exclusively while nogo runs, so stop the service before importing.

## Linux (systemd)

`init/linux-systemd/install.sh` sets the whole thing up:

```
go build -o nogo .
sudo init/linux-systemd/install.sh
```

It installs the binary to `/usr/local/bin/nogo`, creates a `nogo` system user with its database in `/var/lib/nogo/nogo.db`, enables `nogo.service`, imports the fakenews blacklist on first run, and points the system resolver at nogo.

The DNS chain ends up as:

```
application -> systemd-resolved (127.0.0.53, caches) -> nogo (127.0.0.1) -> 1.1.1.1 / 8.8.8.8
```

systemd-resolved stays in front so we keep its cache and its `/etc/resolv.conf` handling. Two drop-ins do the wiring:

* `/etc/systemd/resolved.conf.d/50-nogo.conf` — `DNS=127.0.0.1` and `Domains=~.`, making nogo the global resolver.
* `/etc/NetworkManager/conf.d/50-nogo-dns.conf` — a `[global-dns-domain-*]` override, so the DNS servers handed out by DHCP don't win over nogo on any network the machine joins.

Since nogo becomes the only path to DNS, the unit uses `Restart=always`. Check it with:

```
systemctl status nogo
resolvectl status                    # links should list 127.0.0.1
resolvectl query infowars.com        # should fail
```

Control panel: <http://127.0.0.1:8123/>.

To back out, remove the two drop-ins, `systemctl disable --now nogo`, then `systemctl restart systemd-resolved && systemctl reload NetworkManager`.

## macOS (launchd)

This is `/Library/LaunchDaemons/is.bep.dns.plist`, with the database in `~/config/nogo` and the binary in `~/go/bin`. Adjust the paths.

```xml
<!DOCTYPE plist PUBLIC -//Apple Computer//DTD PLIST 1.0//EN http://www.apple.com/DTDs/PropertyList-1.0.dtd >
<plist version="1.0">
  <dict>
    <key>Label</key>
    <string>com.is.dns</string>
    <key>ProgramArguments</key>
    <array>
      <string>/Users/bep/go/bin/nogo</string>
      <string>-web-addr</string>
      <string>:8123</string>
      <string>-dns-proxyto</string>
      <string>1.1.1.1:53,8.8.8.8:53,8.8.4.4:53</string>
      <string>-db</string>
      <string>/Users/bep/config/nogo/nogo.db</string>
    </array>
    <key>KeepAlive</key>
    <true/>
    <key>RunAtLoad</key>
    <true/>
    <key>StandardOutPath</key>
    <string>/var/log/nogo.log</string>
    <key>StandardErrorPath</key>
    <string>/var/log/nogo.log</string>
  </dict>
</plist>
```

Point *System Settings → Network → DNS* at `127.0.0.1`.

## Refreshing the blacklist

On Linux, `nogo-update-hosts` (installed by `install.sh`) stops the service, downloads the list, imports it and starts the service again:

```
sudo nogo-update-hosts                       # StevenBlack fakenews list
sudo nogo-update-hosts <url-or-file>         # some other list
```

On macOS:

```
sudo launchctl unload /Library/LaunchDaemons/is.bep.dns.plist
wget https://raw.githubusercontent.com/StevenBlack/hosts/master/alternates/fakenews/hosts
nogo -db ~/config/nogo/nogo.db -import hosts
sudo launchctl load -w /Library/LaunchDaemons/is.bep.dns.plist
```

Importing merges into the existing blacklist; it never removes records. To start clean, delete the database file first.

Records paused from the control panel are stored as records with `paused: true` and are resolved normally, so a re-import doesn't undo them.
