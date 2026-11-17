# Bambu Studio browser desktop

This Compose app runs LinuxServer's Bambu Studio desktop embedded in the website page `../../tools/bambu-studio.html`.

## Keep it private

The desktop has a terminal with passwordless `sudo` inside the container. Keep it on your trusted home LAN and do not forward port `3001` from your router. The `CUSTOM_USER` and `PASSWORD` settings below add a login for home-network use; they are not sufficient protection for a public internet deployment.

For access away from home, use a private VPN on both the Proxmox side and the Android device. Do not put this app behind the temporary Cloudflare Quick Tunnel used by the printer-status API. A public Cloudflare Tunnel would need a stable Cloudflare-managed hostname and an Access policy in front of the app.

Use a separate VM for this desktop when possible, rather than installing Docker inside the existing printer-status LXC. This keeps the desktop's privileged session separate from the read-only status service.

## Start

1. Copy `.env.example` to `.env`.
2. Set `BAMBU_STUDIO_USER` and `BAMBU_STUDIO_PASSWORD` to a unique username and long password. Keep `.env` private; it is ignored by Git.
3. From this directory, run `docker compose up -d`.
4. On each device, open `https://192.168.1.250:3001/` once and accept the self-signed HTTPS certificate only after checking the IP. Return to the website's Bambu Studio page to use the embedded desktop.
5. `SELKIES_FRAME_ANCESTORS` allows the GitHub Pages origin and local loopback previews to embed the desktop. Keep this list limited to origins you control.

The app needs a 1 GB shared-memory segment (`shm_size`). The container image is x86-64 compatible; GPU passthrough is optional. The embedded page uses Selkies' streaming client; its Content Security Policy must allow the website origin through `SELKIES_FRAME_ANCESTORS`.

For remote use, replace the LAN address in that browser with the VM's private VPN hostname. Install the VPN client on the Android device and sign into the same private network first.

Upstream image and security notes: <https://github.com/linuxserver/docker-bambustudio>.
