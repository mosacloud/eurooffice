#!/bin/sh

service postgresql start
service rabbitmq-server start
service redis-server start
service nginx start

#tail -f /dev/null
/usr/bin/documentserver-generate-allfonts.sh

NODE_ENV=development-linux NODE_CONFIG_DIR=/etc/onlyoffice/documentserver NODE_DISABLE_COLORS=1 APPLICATION_NAME=ONLYOFFICE LD_LIBRARY_PATH=/var/www/onlyoffice/documentserver/server/FileConverter/bin /bin/sh -c 'cd /var/www/onlyoffice/documentserver/server/FileConverter && exec /var/www/onlyoffice/documentserver/server/FileConverter/converter 2>&1 | tee -a /var/log/onlyoffice/documentserver/converter/out.log' &
NODE_ENV=development-linux NODE_CONFIG_DIR=/etc/onlyoffice/documentserver NODE_DISABLE_COLORS=1 APPLICATION_NAME=ONLYOFFICE /bin/sh -c 'cd /var/www/onlyoffice/documentserver/server/AdminPanel && /var/www/onlyoffice/documentserver/server/AdminPanel/server/adminpanel 2>&1 | tee -a /var/log/onlyoffice/documentserver/adminpanel/out.log' &
NODE_DISABLE_COLORS=1 /bin/sh -c 'cd /var/www/onlyoffice/documentserver/server/Metrics && exec /var/www/onlyoffice/documentserver/server/Metrics/metrics ./config/config.js 2>&1 | tee -a /var/log/onlyoffice/documentserver/metrics/out.log' &
NODE_ENV=development-linux NODE_CONFIG_DIR=/etc/onlyoffice/documentserver NODE_DISABLE_COLORS=1 APPLICATION_NAME=ONLYOFFICE /bin/sh -c 'cd /var/www/onlyoffice/documentserver/server/DocService && exec /var/www/onlyoffice/documentserver/server/DocService/docservice 2>&1 | tee -a /var/log/onlyoffice/documentserver/docservice/out.log' 
