# Bambu Studio browser desktop

This Compose app runs LinuxServer's Bambu Studio desktop embedded in the website page `../../tools/bambu-studio.html`.

## Authentication and network access

The desktop has a terminal with passwordless `sudo` inside the container. This Compose setup leaves LinuxServer's `CUSTOM_USER` and `PASSWORD` unset, so there is no extra desktop login prompt. The Cloudflare Access email PIN protects the public `studio.pinoyproto3d.stream` route. The direct LAN address on port `3001` does not use Cloudflare Access and has no login; only use it on a trusted home network, and do not forward port `3001` from your router.

Use a separate VM for this desktop when possible, rather than installing Docker inside the existing printer-status LXC. This keeps the desktop's privileged session separate from the read-only status service.

## Start

1. Copy `.env.example` to `.env` if you need to change the default PUID or PGID.
2. From this directory, run `docker compose up -d`.
3. In the website's Bambu Studio page, click **Sign in, then return here**. Complete Cloudflare Access in the new tab, then close that tab; the page loads the desktop in its iframe.
4. `SELKIES_FRAME_ANCESTORS` allows the custom website origin, the old GitHub Pages origin, and local loopback previews to embed the desktop. Keep this list limited to origins you control.

The app needs a 1 GB shared-memory segment (`shm_size`). The container image is x86-64 compatible; GPU passthrough is optional. The embedded page uses Selkies' streaming client; its Content Security Policy must allow the website origin through `SELKIES_FRAME_ANCESTORS`.

Upstream image and security notes: <https://github.com/linuxserver/docker-bambustudio>.
