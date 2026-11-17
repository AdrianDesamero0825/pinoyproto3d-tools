#!/usr/bin/env bash
# Read-only Proxmox and LXC 101 status collector.
# Does not print service environment variables, tokens, passwords, or container env.
set -u

section() { printf '\n=== %s ===\n' "$1"; }

section "Proxmox host"
printf 'hostname: '; hostname
printf 'time: '; date -Is
printf 'uptime: '; uptime -p 2>/dev/null || uptime
printf '\nProxmox version:\n'; pveversion -v 2>/dev/null | head -n 8 || true
printf '\nContainers:\n'; pct list 2>/dev/null || true
printf '\nMemory:\n'; free -h 2>/dev/null || true
printf '\nFilesystem:\n'; df -h / /var/lib/vz 2>/dev/null || true
printf '\nHost interfaces (local addresses):\n'; ip -br address 2>/dev/null || true

section "LXC 101 configuration summary"
pct status 101 2>/dev/null || true
pct config 101 2>/dev/null | awk -F': ' '
  /^(cores|memory|swap|rootfs):/ {print}
  /^net[0-9]+:/ {
    line=$2
    gsub(/hwaddr=[^,]+,?/, "", line)
    gsub(/,ip6=dhcp/, "", line)
    print "network: " line
  }
'

section "LXC 101 services and Docker"
pct exec 101 -- sh -lc '
  printf "time: "; date -Is
  printf "hostname: "; hostname
  printf "systemd services:\n"
  for unit in docker pinoyproto-bambu-control pinoyproto-bambu-idle-watchdog.timer; do
    printf "  %-42s " "$unit"
    systemctl is-active "$unit" 2>/dev/null || true
  done
  printf "\nDocker containers (name, image, state, ports):\n"
  docker ps -a --format "table {{.Names}}\t{{.Image}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || true
  printf "\nDocker usage:\n"
  docker system df 2>/dev/null || true
  printf "\nContainer disk and memory:\n"
  df -h / /opt 2>/dev/null || true
  free -h 2>/dev/null || true
  printf "\nWatchdog timer:\n"
  systemctl list-timers --all pinoyproto-bambu-idle-watchdog.timer --no-pager 2>/dev/null || true
  printf "\nWatchdog last-active timestamp:\n"
  f=/var/lib/pinoyproto-bambu-idle-watchdog/last-active
  if [ -r "$f" ]; then date -d "@$(cat "$f")" -Is 2>/dev/null || cat "$f"; else echo "none (no pending idle countdown)"; fi
  printf "\nBambu control API health:\n"
  curl --max-time 4 -fsS http://127.0.0.1:8788/health 2>/dev/null || echo "unavailable"
  printf "\nEstablished desktop TCP connections:\n"
  ss -Htn state established "( sport = :3001 )" 2>/dev/null | wc -l
  printf "Selkies session API count:\n"
  if [ -x /usr/local/sbin/pinoyproto-bambu-sessions ]; then
    /usr/local/sbin/pinoyproto-bambu-sessions 2>/dev/null | python3 -c "import json,sys; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "unavailable"
  else
    echo "helper not installed"
  fi
' 2>/dev/null || echo "Could not query LXC 101 from this host."

section "End of read-only report"
echo "No configuration was changed. Review local IP addresses before sharing."
