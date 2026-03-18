#!/usr/bin/env bash
# provision-deb.sh — Vagrant provisioner for Debian/Ubuntu VMs.
# Installs prerequisites, the .deb package from /pkgs, and starts all services.
# The VM is left running for manual inspection.
set -euo pipefail

PKG_DIR="/pkgs"
DEB=$(ls "${PKG_DIR}"/*.deb 2>/dev/null | head -1 || true)

if [ -z "$DEB" ]; then
  echo "ERROR: No .deb found in ${PKG_DIR}. Run 'make packages' first." >&2
  exit 1
fi

echo "========================================================"
echo " Installing: $(basename "$DEB")"
echo "========================================================"

# ---------------------------------------------------------------------------
# 1. Install prerequisites
# ---------------------------------------------------------------------------
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq

apt-get install -y --no-install-recommends \
  postgresql redis-server rabbitmq-server \
  nginx supervisor \
  curl sudo ca-certificates apt-utils

# ---------------------------------------------------------------------------
# 2. Start and configure PostgreSQL
# ---------------------------------------------------------------------------
systemctl enable --now postgresql
sleep 2

sudo -u postgres psql -tc "SELECT 1 FROM pg_roles WHERE rolname='onlyoffice'" \
  | grep -q 1 || \
  sudo -u postgres psql -c "CREATE USER onlyoffice WITH PASSWORD 'onlyoffice';"

sudo -u postgres psql -tc "SELECT 1 FROM pg_database WHERE datname='onlyoffice'" \
  | grep -q 1 || \
  sudo -u postgres psql -c "CREATE DATABASE onlyoffice OWNER onlyoffice;"

# ---------------------------------------------------------------------------
# 3. Start Redis and RabbitMQ
# ---------------------------------------------------------------------------
systemctl enable --now redis-server
systemctl enable --now rabbitmq-server

# ---------------------------------------------------------------------------
# 4. Pre-accept mscorefonts EULA and install the .deb
# ---------------------------------------------------------------------------
echo "ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true" \
  | debconf-set-selections

apt-get install -y --fix-broken "$DEB"

# ---------------------------------------------------------------------------
# 5. Start document server services
# ---------------------------------------------------------------------------
# Flush cache to generate ds-cache.conf for nginx
if command -v documentserver-flush-cache.sh &>/dev/null; then
  documentserver-flush-cache.sh -r false || true
fi

# Enable and start the document server systemd services
for svc in ds-docservice ds-converter ds-metrics; do
  if systemctl list-unit-files "${svc}.service" &>/dev/null; then
    systemctl enable --now "${svc}" || true
  fi
done

# Restart nginx to pick up the document server config
systemctl restart nginx || true

# ---------------------------------------------------------------------------
# 6. Print status
# ---------------------------------------------------------------------------
echo ""
echo "========================================================"
echo " Provisioning complete"
echo "========================================================"
echo ""
echo "Services:"
for svc in postgresql redis-server rabbitmq-server nginx ds-docservice ds-converter ds-metrics; do
  printf "  %-25s %s\n" "$svc" "$(systemctl is-active "$svc" 2>/dev/null || echo 'unknown')"
done
echo ""
echo "Healthcheck URL (inside VM):  curl -sf http://localhost/healthcheck"
echo "Healthcheck URL (from host):  curl -sf http://localhost:<forwarded-port>/healthcheck"
echo ""
echo "The document server may take a minute to fully initialize (font generation, etc.)."
echo "SSH in with:  vagrant ssh <vm-name>"
