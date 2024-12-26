#!/bin/sh

# Set the timezone
ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Generate crontab entry dynamically
echo "$CRON_SCHEDULE /scripts/getservices.sh > /var/www/html/docker_containers.html" > /etc/crontabs/root

# Start cron daemon in the background
crond -L /var/log/cron.log &

# Start NGINX in the foreground
nginx -g 'daemon off;' &

# Run the `getservices.sh` script once asynchronously
/scripts/getservices.sh > /var/www/html/docker_containers.html &

# Wait for all processes to complete
wait
