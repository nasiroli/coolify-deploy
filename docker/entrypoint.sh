#!/bin/sh
set -e

if [ "$AUTORUN_ENABLED" = "true" ]; then
    php /var/www/html/artisan migrate --force
fi

exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
