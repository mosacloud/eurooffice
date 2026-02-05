#!/bin/sh

service postgresql start
service rabbitmq-server start
service redis-server start
service nginx start

#tail -f /dev/null
/usr/bin/documentserver-generate-allfonts.sh


/usr/bin/supervisord