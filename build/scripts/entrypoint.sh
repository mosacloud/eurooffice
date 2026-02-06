#!/bin/sh

service postgresql start
service rabbitmq-server start
service redis-server start
service nginx start

#tail -f /dev/null
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

if [ "$jq_filter" != "." ]; then
  jq \
    --arg jwtSecret "$JWT_SECRET" \
    --arg dbPassword "$DB_PASSWORD" \
    "$jq_filter" \
    "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"

  mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
fi

/usr/bin/supervisord