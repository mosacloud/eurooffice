#!/bin/sh

# Create symlink for /config -> /etc/onlyoffice/documentserver so tools can find config
ln -sf /etc/onlyoffice/documentserver /config 2>/dev/null || true

service postgresql start
service rabbitmq-server start
service redis-server start
service nginx start

# Ensure the api.js.tpl template exists (required by documentserver-flush-cache.sh)
API_TPL="/var/www/onlyoffice/documentserver/web-apps/apps/api/documents/api.js.tpl"
if [ ! -f "$API_TPL" ] && [ -f "/var/www/onlyoffice/documentserver/web-apps/apps/api/documents/api.js" ]; then
    cp /var/www/onlyoffice/documentserver/web-apps/apps/api/documents/api.js "$API_TPL"
fi

# Generate all fonts (AllFonts.js, font_selection.bin, presentation themes)
/usr/bin/documentserver-generate-allfonts.sh



CONFIG_FILE="$EO_CONF/local.json"

jq_filter='.'

[ -n "$JWT_SECRET" ] && \
  jq_filter="$jq_filter | .services.CoAuthoring.secret.browser.string = \$jwtSecret"
  jq_filter="$jq_filter | .services.CoAuthoring.secret.inbox.string   = \$jwtSecret"
  jq_filter="$jq_filter | .services.CoAuthoring.secret.outbox.string  = \$jwtSecret"
  jq_filter="$jq_filter | .services.CoAuthoring.secret.session.string = \$jwtSecret"

[ -n "$DB_PASSWORD" ] && \
  jq_filter="$jq_filter | .services.CoAuthoring.sql.dbPass = \$dbPassword"

[ -n "$USE_UNAUTHORIZED_STORAGE" ] && \
  jq_filter="$jq_filter | .services.CoAuthoring.requestDefaults.rejectUnauthorized = false"

[ -n "$ALLOW_PRIVATE_IP_ADDRESS" ] && \
  jq_filter="$jq_filter | .services.CoAuthoring[\"request-filtering-agent\"].allowPrivateIPAddress = true"

[ -n "$ALLOW_META_IP_ADDRESS" ] &&\
  jq_filter="$jq_filter | .services.CoAuthoring["request-filtering-agent"].allowMetaIPAddress = true"

if [ "$jq_filter" != "." ]; then
  jq \
    --arg jwtSecret "$JWT_SECRET" \
    --arg dbPassword "$DB_PASSWORD" \
    "$jq_filter" \
    "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"

  mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
fi

/usr/bin/supervisord