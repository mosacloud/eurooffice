#!/bin/sh

service postgresql start
service rabbitmq-server start
service redis-server start
service nginx start

#tail -f /dev/null
/usr/bin/documentserver-generate-allfonts.sh

NODE_ENV=production-linux NODE_CONFIG_DIR=/etc/onlyoffice/documentserver NODE_DISABLE_COLORS=1 APPLICATION_NAME=ONLYOFFICE /var/www/onlyoffice/documentserver/server/FileConverter/converter &
NODE_ENV=production-linux NODE_CONFIG_DIR=/etc/onlyoffice/documentserver NODE_DISABLE_COLORS=1 APPLICATION_NAME=ONLYOFFICE /var/www/onlyoffice/documentserver/server/DocService/docservice

