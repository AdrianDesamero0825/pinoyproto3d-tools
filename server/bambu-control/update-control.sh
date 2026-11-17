#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this update as root inside Proxmox container 101." >&2
  exit 1
fi

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/opt/pinoyproto-bambu-control"
for required in main.py pinoyproto-bambu-control pinoyproto-bambu-sessions; do
  if [ ! -f "$SOURCE_DIR/$required" ]; then
    echo "Missing $SOURCE_DIR/$required. Copy the updated files first." >&2
    exit 1
  fi
done

if ! id bambu-control >/dev/null 2>&1; then
  echo "The bambu-control service account is missing. Use install-control.sh first." >&2
  exit 1
fi

install -d -o root -g root -m 755 "$APP_DIR"
install -o root -g root -m 644 "$SOURCE_DIR/main.py" "$APP_DIR/main.py"
install -o root -g root -m 755 "$SOURCE_DIR/pinoyproto-bambu-control" /usr/local/sbin/pinoyproto-bambu-control
install -o root -g root -m 755 "$SOURCE_DIR/pinoyproto-bambu-sessions" /usr/local/sbin/pinoyproto-bambu-sessions

if ! command -v sudo >/dev/null 2>&1; then
  apt-get update
  apt-get install -y sudo
fi
printf '%s\n' 'bambu-control ALL=(root) NOPASSWD: /usr/local/sbin/pinoyproto-bambu-control status, /usr/local/sbin/pinoyproto-bambu-control watch, /usr/local/sbin/pinoyproto-bambu-control sessions, /usr/local/sbin/pinoyproto-bambu-control start, /usr/local/sbin/pinoyproto-bambu-control stop' > /etc/sudoers.d/pinoyproto-bambu-control
chown root:root /etc/sudoers.d/pinoyproto-bambu-control
chmod 440 /etc/sudoers.d/pinoyproto-bambu-control
visudo -cf /etc/sudoers.d/pinoyproto-bambu-control

# The API now controls Docker inside this container and no longer needs Proxmox credentials.
if [ -f /etc/pinoyproto-bambu-control.env ]; then
  sed -i -E '/^PROXMOX_(API_URL|TOKEN_ID|TOKEN_SECRET|NODE|CONTAINER_ID|CA_FILE)=/d' /etc/pinoyproto-bambu-control.env
  chmod 600 /etc/pinoyproto-bambu-control.env
fi

systemctl restart pinoyproto-bambu-control.service
echo "Bambu Studio control API updated and restarted."
