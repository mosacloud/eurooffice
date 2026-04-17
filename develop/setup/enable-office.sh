#!/bin/bash

php /var/www/html/occ config:system:set trusted_domains 2 --value=nextcloud

echo "Waiting for Euro-Office document server to be ready..."
until curl -sf http://eo/healthcheck > /dev/null 2>&1; do
    echo "Waiting for http://eo/healthcheck..."
    sleep 5
done
echo "Document server is ready!"

php /var/www/html/occ app:enable onlyoffice
php /var/www/html/occ config:app:set onlyoffice DocumentServerUrl --value="http://localhost:8080/"
php /var/www/html/occ config:app:set onlyoffice StorageUrl --value="http://nextcloud/"
php /var/www/html/occ config:app:set onlyoffice DocumentServerInternalUrl --value="http://eo/"
php /var/www/html/occ config:app:set onlyoffice VerifyPeerOff --value="true"
php /var/www/html/occ config:app:set onlyoffice jwt_secret --value="secret"

