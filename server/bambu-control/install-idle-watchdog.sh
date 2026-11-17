#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this installer as root inside Proxmox container 101." >&2
  exit 1
fi

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
for required in pinoyproto-bambu-idle-watchdog pinoyproto-bambu-idle-watchdog.service pinoyproto-bambu-idle-watchdog.timer; do
  if [ ! -f "$SOURCE_DIR/$required" ]; then
    echo "Missing $SOURCE_DIR/$required. Copy the complete bambu-control folder first." >&2
    exit 1
  fi
done

command -v docker >/dev/null 2>&1 || { echo "Docker is not installed in this container." >&2; exit 1; }
command -v ss >/dev/null 2>&1 || { echo "Install iproute2 first; it provides ss." >&2; exit 1; }

install -o root -g root -m 755 "$SOURCE_DIR/pinoyproto-bambu-idle-watchdog" /usr/local/sbin/pinoyproto-bambu-idle-watchdog
install -o root -g root -m 644 "$SOURCE_DIR/pinoyproto-bambu-idle-watchdog.service" /etc/systemd/system/pinoyproto-bambu-idle-watchdog.service
install -o root -g root -m 644 "$SOURCE_DIR/pinoyproto-bambu-idle-watchdog.timer" /etc/systemd/system/pinoyproto-bambu-idle-watchdog.timer
install -d -o root -g root -m 700 /var/lib/pinoyproto-bambu-idle-watchdog

systemctl daemon-reload
systemctl enable --now pinoyproto-bambu-idle-watchdog.timer

echo "Watchdog timer enabled. It checks every 30 seconds and stops only Docker container bambu-studio after 15 minutes without an active desktop connection."
systemctl --no-pager --full status pinoyproto-bambu-idle-watchdog.timer
