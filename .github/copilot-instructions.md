# Copilot instructions for this repo

## Big picture
- Jelastic addon for WordPress Multisite + LiteSpeed that provisions one vHost + one Let’s Encrypt cert per domain.
- Entry point is the Jelastic manifest [manifest.jps](manifest.jps), which wires install actions to shell scripts in scripts/.
- Domain provisioning flow: `addDomain` action → [scripts/add-domain.sh](scripts/add-domain.sh) → certbot cert + vHost conf generated from [templates/litespeed-vhost.conf](templates/litespeed-vhost.conf) → reload LiteSpeed.

## Key components and data flow
- [manifest.jps](manifest.jps) defines user inputs (`domain`, `email`) and maps actions to scripts.
- [scripts/install-base.sh](scripts/install-base.sh) installs certbot (yum/epel) and configures cron renewal + LiteSpeed reload.
- [scripts/add-domain.sh](scripts/add-domain.sh) uses certbot `--webroot` with `DOCROOT=/var/www/webroot/ROOT`, writes vHost at `/var/www/conf/vhosts/$DOMAIN/vhconf.conf`, then reloads `lsws`.
- [templates/litespeed-vhost.conf](templates/litespeed-vhost.conf) is a template with `{DOMAIN}` placeholder; it is substituted via `sed` in `add-domain.sh`.

## Conventions specific to this project
- All paths are hard-coded for the Jelastic/LiteSpeed layout (e.g., `/var/www/conf/vhosts`, `/var/www/webroot/ROOT`). Keep these consistent unless the change is intentional.
- vHost creation uses a simple text template; update the template rather than inlining config in the script.
- Placeholder format is `{DOMAIN}`; if you add new placeholders, keep the same `{NAME}` style and update the `sed` logic.
- The addon assumes a CentOS/RHEL-like environment (`yum`, `systemctl`). Avoid Debian-specific tooling unless you also add compatibility logic.

## Developer workflows
- Installation and actions are executed by Jelastic from the manifest; there is no local build/test pipeline in this repo.
- To add a new addon action, update `manifest.jps` and create a script in scripts/; follow the existing `bash scripts/...` pattern.

## Integration points
- External dependency: `certbot` (installed via yum/epel) and Let’s Encrypt ACME servers.
- LiteSpeed reload is done with `systemctl reload lsws`; changes to vHost config rely on this service name.
