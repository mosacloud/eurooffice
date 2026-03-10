#!/bin/sh

while [ "$1" != "" ]; do
	case $1 in

		-h | --hash )
			if [ "$2" != "" ]; then
				HASH=$2
				shift
			fi
		;;

                -r | --restart )
                        if [ "$2" != "" ]; then
                                RESTART_CONDITION=$2
                                shift
                        fi
                ;;

	esac
	shift
done

HASH=${HASH:-$(date +'%Y.%m.%d' | openssl md5 | awk '{print $2}')}

# Save the hash to a variable in the configuration file
echo "set \$cache_tag \"$HASH\";" > /etc/nginx/includes/ds-cache.conf

API_PATH="/var/www/onlyoffice/documentserver/web-apps/apps/api/documents/api.js"
# Only copy template if it exists, otherwise create from existing api.js if available
if [ -f "${API_PATH}.tpl" ]; then
    cp -f ${API_PATH}.tpl ${API_PATH}
elif [ -f "$API_PATH" ]; then
    # If no template, use the existing file (first run scenario)
    cp -f $API_PATH ${API_PATH}.tpl 2>/dev/null || true
fi
sed -i "s/{{HASH_POSTFIX}}/${HASH}/g" ${API_PATH} 2>/dev/null || true
# Only chown if ds user exists
if id -u ds > /dev/null 2>&1; then
    chown ds:ds ${API_PATH}
fi
rm -f ${API_PATH}.gz

if [ "$RESTART_CONDITION" != "false" ]; then
    if (pgrep -x "systemd" > /dev/null) && systemctl is-active --quiet nginx; then
        systemctl reload nginx
    elif service nginx status > /dev/null 2>&1; then
        service nginx reload
    fi
fi
