#!/usr/bin/env bash
set -euo pipefail

if [ "$(id -u)" -ne 0 ]; then
  echo "Run this installer as root inside Proxmox container 101." >&2
  exit 1
fi

SOURCE_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
APP_DIR="/opt/pinoyproto-bambu-control"
for required in main.py requirements.txt pinoyproto-bambu-control pinoyproto-bambu-control.service; do
  if [ ! -f "$SOURCE_DIR/$required" ]; then
    echo "Missing $SOURCE_DIR/$required. Copy the complete bambu-control folder first." >&2
    exit 1
  fi
done

read -r -p "Supabase admin email allowed to control Bambu Studio: " ADMIN_EMAIL
if [ -z "$ADMIN_EMAIL" ] || [[ "$ADMIN_EMAIL" == *[[:space:]]* ]]; then
  echo "A valid admin email is required." >&2
  exit 1
fi

if ! id bambu-control >/dev/null 2>&1; then
  useradd --system --home-dir /nonexistent --shell /usr/sbin/nologin bambu-control
fi

APT_PACKAGES=()
PYTHON_VERSION="$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')"
dpkg-query -W -f='${Status}' "python${PYTHON_VERSION}-venv" 2>/dev/null | grep -qx 'install ok installed' || APT_PACKAGES+=("python${PYTHON_VERSION}-venv")
command -v curl >/dev/null 2>&1 || APT_PACKAGES+=(curl)
command -v sudo >/dev/null 2>&1 || APT_PACKAGES+=(sudo)
if [ "${#APT_PACKAGES[@]}" -gt 0 ]; then
  apt-get update
  apt-get install -y "${APT_PACKAGES[@]}"
fi

install -d -o root -g root -m 755 "$APP_DIR"
install -o root -g root -m 644 "$SOURCE_DIR/main.py" "$APP_DIR/main.py"
install -o root -g root -m 644 "$SOURCE_DIR/requirements.txt" "$APP_DIR/requirements.txt"
install -o root -g root -m 755 "$SOURCE_DIR/pinoyproto-bambu-control" /usr/local/sbin/pinoyproto-bambu-control
printf '%s\n' 'bambu-control ALL=(root) NOPASSWD: /usr/local/sbin/pinoyproto-bambu-control status, /usr/local/sbin/pinoyproto-bambu-control watch, /usr/local/sbin/pinoyproto-bambu-control start, /usr/local/sbin/pinoyproto-bambu-control stop' > /etc/sudoers.d/pinoyproto-bambu-control
chown root:root /etc/sudoers.d/pinoyproto-bambu-control
chmod 440 /etc/sudoers.d/pinoyproto-bambu-control
visudo -cf /etc/sudoers.d/pinoyproto-bambu-control
python3 -m venv --clear "$APP_DIR/.venv"
"$APP_DIR/.venv/bin/pip" install --disable-pip-version-check -r "$APP_DIR/requirements.txt"

cat > /etc/pinoyproto-bambu-control.env <<EOF
SUPABASE_URL=https://cifxwhhdkmecgomwesnk.supabase.co
SUPABASE_PUBLISHABLE_KEY=sb_publishable_4-at96mA3nKEH6t2irolAg_20waHMZo
BAMBU_ADMIN_EMAILS=$ADMIN_EMAIL
CONTROL_ALLOWED_ORIGINS=https://www.pinoyproto3d.stream,https://adriandesamero0825.github.io,http://localhost:5500,http://127.0.0.1:5500
EOF
chown root:root /etc/pinoyproto-bambu-control.env
chmod 600 /etc/pinoyproto-bambu-control.env

install -o root -g root -m 644 "$SOURCE_DIR/pinoyproto-bambu-control.service" /etc/systemd/system/pinoyproto-bambu-control.service
systemctl daemon-reload
systemctl enable pinoyproto-bambu-control.service
systemctl restart pinoyproto-bambu-control.service

echo
systemctl --no-pager --full status pinoyproto-bambu-control.service || true
echo
echo "Local API health check:"
for attempt in $(seq 1 15); do
  if curl --fail --silent http://127.0.0.1:8788/health; then
    echo
    exit 0
  fi
  sleep 1
done
echo "The service did not become healthy. Review: journalctl -u pinoyproto-bambu-control.service -n 50 --no-pager" >&2
exit 1
