# Dreambox NTP Sync 1.1.0

English | [العربية](README-AR.md)

Dreambox NTP Sync is a lightweight system-level time synchronization service for Dreambox receivers running Enigma2. It works with Python 2.7 and Python 3 and does not depend on a specific Enigma2 image.

## Requirements

- A Dreambox receiver running Enigma2.
- A DEB-based image with `dpkg` and `dpkg-query`.
- Python 2.7 or Python 3.
- An active internet connection for NTP synchronization.
- `wget` or `curl` for automatic installation.

## One-command installation

Connect to the receiver through Telnet or SSH as `root`, then run:

```sh
wget -qO- "https://raw.githubusercontent.com/Saiedf/DreamboxNTP/main/installer_dreambox_ntp_sync_auto.sh?nocache=$(date +%s)" | /bin/sh
```

The installer automatically:

- Reads the latest version from `ver.txt`.
- Downloads the matching DEB package from `Releases`.
- Purges an installed earlier version.
- Removes known files, services, logs and cache files left by version 1.0.0.
- Removes the older DreamTimeSync plugin when detected to prevent conflicting time updates and recurring messages.
- Installs the new package.
- Reloads systemd and enables the synchronization timer.
- Runs an immediate synchronization check.
- Verifies the installed version and service.
- Shows one installation-success message and restarts Enigma2 automatically.

No additional installation steps or user input are required.

## Manual installation

Download and copy this file to `/tmp`:

```text
dreambox-ntp-sync_1.1.0_all.deb
```

Then run:

```sh
dpkg -i /tmp/dreambox-ntp-sync_1.1.0_all.deb
systemctl daemon-reload
systemctl enable --now dreambox-ntp-sync.timer
systemctl start dreambox-ntp-sync.service
systemctl restart enigma2
```

## Verification

```sh
/usr/bin/dreambox-ntp-sync --version
systemctl status dreambox-ntp-sync.timer --no-pager
systemctl status dreambox-ntp-sync.service --no-pager
cat /tmp/dreambox-ntp-sync.log
date
```

The timer should show `active (waiting)`. The service is a one-shot service and may show `inactive (dead)` after a successful run; this is normal.

## Log file

Synchronization results are written to:

```text
/tmp/dreambox-ntp-sync.log
```

The synchronization service runs silently in the background and does not display recurring on-screen messages. The automatic installer may display one success message when installation finishes.

## Uninstallation

```sh
dpkg --purge dreambox-ntp-sync
systemctl daemon-reload
```

## GitHub release layout

```text
README.md
README-AR.md
ver.txt
installer_dreambox_ntp_sync_auto.sh
Releases/dreambox-ntp-sync_1.1.0_all.deb
```
