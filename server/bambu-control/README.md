# Bambu Studio power controls

This companion API lets the website admin check, start, or stop only the Docker container named `bambu-studio`. It does not expose the Docker socket or accept arbitrary Docker commands. Run it on the Bambu host or another trusted machine that can reach Docker locally.

## Install on the Docker host

1. Copy `pinoyproto-bambu-control` to `/usr/local/sbin/pinoyproto-bambu-control`, owned by root and not writable by the API account. Confirm Docker is installed at `/usr/bin/docker`; adjust the helper if it is elsewhere.
2. Create a dedicated unprivileged account named `bambu-control` and a Python virtual environment for this API.
3. Install `requirements.txt` into that environment and copy `main.py` to a root-owned application directory readable but not writable by `bambu-control`.
4. Create `/etc/sudoers.d/pinoyproto-bambu-control` with the API account name and these exact command grants (replace `bambu-control` if you chose another account):

   ```sudoers
   bambu-control ALL=(root) NOPASSWD: /usr/local/sbin/pinoyproto-bambu-control status, /usr/local/sbin/pinoyproto-bambu-control start, /usr/local/sbin/pinoyproto-bambu-control stop
   ```

   Validate it with `visudo -cf /etc/sudoers.d/pinoyproto-bambu-control`. Do not add the API account to the Docker group; the restricted helper is the only privileged path.
5. Create a root-owned environment file for the service with:

   ```ini
   SUPABASE_URL=https://cifxwhhdkmecgomwesnk.supabase.co
   SUPABASE_PUBLISHABLE_KEY=sb_publishable_4-at96mA3nKEH6t2irolAg_20waHMZo
   BAMBU_ADMIN_EMAILS=your-admin-email@example.com
   CONTROL_ALLOWED_ORIGINS=https://adriandesamero0825.github.io,http://localhost:5500,http://127.0.0.1:5500
   ```

   Set `BAMBU_ADMIN_EMAILS` to the exact Supabase Auth email allowed to operate the container. The publishable key is public by design; never put a Supabase secret or service-role key in this service or website.
6. Install the included systemd unit (edit its working directory and virtual-environment paths to match your install) and run Uvicorn bound to `127.0.0.1:8788`, not `0.0.0.0`. If published through Cloudflare Tunnel, configure Access to allow only your identity. Do not create a public unauthenticated route to this API. Because the website calls this API cross-origin, the page must send credentials and the API permits credentialed CORS only from the configured exact origins.
7. Set the Bambu Studio page's **Private control service address** to the API's HTTPS hostname, for example `https://studio-control.example.com`.

The website sends its current Supabase access token as a bearer token. This API asks Supabase Auth to validate the token and checks the verified email against `BAMBU_ADMIN_EMAILS`. CORS is restricted to the website origin. Cloudflare Access should also protect the control API hostname as a separate outer gate; sign into the Access-protected hostname in the browser first if Access requires a session before allowing the page's API requests.

The UI's Stop button asks for confirmation because it closes the remote desktop. Save work before stopping. Start and stop act only on the named container; they do not alter its restart policy or remove its data.
