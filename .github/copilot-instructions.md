# Copilot instructions for this repo

## Big picture
- Jelastic addon for WordPress Multisite + LiteSpeed that provisions one vHost + one Let’s Encrypt cert per domain.
- Entry point is the Jelastic manifest [manifest.jps](manifest.jps), which wires install actions to shell scripts in scripts/.
- Domain provisioning flow: `addDomain` action → [scripts/add-domain.sh](scripts/add-domain.sh) → certbot cert + vHost XML generated from [templates/litespeed-vhost.xml](templates/litespeed-vhost.xml) → reload LiteSpeed.
- All scripts log to `/var/log/wp-multisite-ssl-manager.log` with timestamps.

## Key components and data flow
- [manifest.jps](manifest.jps) defines user inputs (`domain`, `email`) and maps actions to scripts.
- [scripts/install-base.sh](scripts/install-base.sh) installs certbot (yum/epel) and configures cron renewal + LiteSpeed reload.
- [scripts/add-domain.sh](scripts/add-domain.sh) uses certbot `--webroot` with `DOCROOT=/var/www/webroot/ROOT`, writes vHost XML at `/var/www/conf/vhosts/$DOMAIN/vhconf.xml`, then reloads `lsws`.
- [templates/litespeed-vhost.xml](templates/litespeed-vhost.xml) is an XML template with `{DOMAIN}` placeholder; it is substituted via `sed` in `add-domain.sh`.
- **CRITICAL**: vHost mapping in HTTPS listeners MUST be placed BEFORE the Jelastic wildcard mapping to ensure SNI works correctly.

## Conventions specific to this project
- All paths are hard-coded for the Jelastic/LiteSpeed layout (e.g., `/var/www/conf/vhosts`, `/var/www/webroot/ROOT`). Keep these consistent unless the change is intentional.
- vHost creation uses an XML template (LiteSpeed 6.x format); update the template rather than inlining config in the script.
- Placeholder format is `{DOMAIN}`; if you add new placeholders, keep the same `{NAME}` style and update the `sed` logic.
- The addon assumes a CentOS/RHEL-like environment (`yum`, `systemctl`). Avoid Debian-specific tooling unless you also add compatibility logic.
- **IMPORTANT**: In HTTPS listeners, specific domain mappings must appear BEFORE wildcard (*) mappings for SNI to route correctly.

## Developer workflows
- Installation and actions are executed by Jelastic from the manifest; there is no local build/test pipeline in this repo.
- To add a new addon action, update `manifest.jps` and create a script in scripts/; follow the existing `bash scripts/...` pattern.

## Integration points
- External dependency: `certbot` (installed via yum/epel) and Let’s Encrypt ACME servers.
- LiteSpeed reload is done with `systemctl reload lsws`; changes to vHost config rely on this service name.
## LiteSpeed 6.x structure

### Key paths
- `/var/www/webroot/ROOT` – WordPress Multisite document root (shared by all domains)
- `/var/www/conf/httpd_config.xml` – Main LiteSpeed configuration (contains listeners and SNI mappings)
- `/var/www/conf/vhosts/$DOMAIN/vhconf.xml` – Per-domain vHost configuration (XML format)
- `/etc/letsencrypt/live/$DOMAIN/` – Let's Encrypt certificates (fullchain.pem, privkey.pem)
- `/var/log/wp-multisite-ssl-manager.log` – Addon log file (all scripts write here with timestamps)

### vHost configuration format
- **LiteSpeed 6.x requires XML format**, not plain text legacy .conf files.
- Template at [templates/litespeed-vhost.xml](templates/litespeed-vhost.xml) contains:
  - `<docRoot>` pointing to shared WordPress root
  - `<index>` files (index.html, index.php)
  - `<htAccess>` enabled for WordPress .htaccess
  - `<vhssl>` section with Let's Encrypt cert paths
  - `<rewrite>` rules for WordPress permalinks
- Placeholder `{DOMAIN}` is substituted via `sed` in add-domain.sh.

### SNI (Server Name Indication) routing
- HTTPS listeners in `/var/www/conf/httpd_config.xml` contain `<vhostMap>` with domain mappings.
- **CRITICAL ORDER**: Specific domain mappings MUST appear BEFORE wildcard (*) mapping.
- Correct order ensures SNI routes requests to the correct vHost with the correct SSL certificate.
- Jelastic default config has a wildcard mapping that catches all domains; new domains must be inserted BEFORE it.
- [scripts/add-domain.sh](scripts/add-domain.sh) uses Python XML manipulation to ensure correct insertion order.

### Logging
- All scripts use a `log()` function that prefixes output with `[YYYY-MM-DD HH:MM:SS]`.
- Output is written to both stdout (for Jelastic panel display) and `/var/log/wp-multisite-ssl-manager.log`.
- Pattern: `exec > >(tee -a "$LOG_FILE") 2>&1` at the top of each script.

### Certificate renewal
- Installed by [scripts/install-base.sh](scripts/install-base.sh) via cron.
- Cron runs `certbot renew` daily; LiteSpeed reload triggered only if certs are renewed.
- No manual intervention required; all domains renewed together.