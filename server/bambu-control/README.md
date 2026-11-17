# Bambu Studio status, power control, and idle shutdown

The Bambu Studio page shows the Docker app's state, active desktop connection count, and the watchdog's approximate idle countdown. It refreshes every 30 seconds for signed-in admins and can start or stop only the `bambu-studio` Docker container. The control API still requires an authenticated Supabase admin and the Cloudflare-protected `/api/bambu/*` tunnel route.

## Update the website control API

The API used to report whether Proxmox LXC 101 was running, which could say “running” even when its Bambu Studio Docker app was stopped. The updated API checks, starts, and stops the Docker app itself. It uses a root-owned command wrapper with narrowly limited `sudo` permissions instead of Proxmox API credentials.

From Windows PowerShell in the project folder, copy the updated files to the Proxmox host:

```powershell
scp -r ".\server\bambu-control" root@192.168.1.105:/root/
```

At the Proxmox host prompt (`root@pve:~#`), push the API and wrapper into LXC 101, then restart the service:

```bash
pct exec 101 -- mkdir -p /root/bambu-control
pct push 101 /root/bambu-control/main.py /root/bambu-control/main.py
pct push 101 /root/bambu-control/pinoyproto-bambu-control /root/bambu-control/pinoyproto-bambu-control
pct push 101 /root/bambu-control/update-control.sh /root/bambu-control/update-control.sh
pct exec 101 -- bash /root/bambu-control/update-control.sh
```

This preserves the existing allowed website admin email and Supabase settings. It removes the old, no-longer-needed Proxmox API token values from the control service environment file.

## 15-minute disconnected-desktop watchdog

The watchdog runs inside LXC 101 and checks every 30 seconds for an established connection to the Bambu Studio desktop on port 3001. After 15 minutes without a desktop connection, it gracefully stops only the `bambu-studio` Docker container. Proxmox and LXC 101 stay on, so the Cloudflare Tunnel and status API remain available.

Install it from the Proxmox host shell:

```bash
pct exec 101 -- bash /root/bambu-control/install-idle-watchdog.sh
pct exec 101 -- systemctl --no-pager status pinoyproto-bambu-idle-watchdog.timer
```

The timer runs the watchdog check every 30 seconds. Its last-active timestamp is stored at `/var/lib/pinoyproto-bambu-idle-watchdog/last-active` inside LXC 101. Watchdog events are logged with the journal tag `pinoyproto-bambu-watchdog`.
