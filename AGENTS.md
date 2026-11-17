# PinoyProto 3D agent guide

Before changing site, database, Cloudflare, or server behavior, read [docs/SYSTEM_OVERVIEW.md](docs/SYSTEM_OVERVIEW.md). If the local-only `docs/private/SYSTEM_AUDIT.md` exists, read it too; it contains current findings that should not be published.

## Project guardrails

- Keep website changes local in this repository until the user explicitly asks to publish them.
- Never put Supabase secret/service-role keys, Cloudflare tunnel tokens, passwords, or other credentials in browser code, docs, commits, or public Pages artifacts.
- Never assume a database policy is restrictive from its name. Inspect its expression and all other permissive policies before changing authorization.
- The Bambu control API must continue to verify the Supabase bearer session and the server-side admin allowlist. Its command wrapper must remain limited to the Bambu Studio Docker container.
- The idle watchdog is intended to stop only the `bambu-studio` Docker container after 15 minutes without a desktop connection. Do not stop the Proxmox host or LXC 101 as part of that flow.
- Keep public GitHub Pages output limited to `index.html`, `assets/`, and `tools/`. Do not copy server code, database migrations, agent instructions, diagnostics, or operational documentation into the Pages artifact.
- Preserve unrelated user edits and follow the applicable local website rules in `.cursor/rules/`.

When describing status, label it as **live verified**, **repository verified**, **conversation-reported**, or **not yet verified**. Never present a past chat transcript as proof of the server's current state.
