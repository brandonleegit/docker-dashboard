# Use a lightweight base image
FROM alpine:latest

# Install required packages
RUN apk add --no-cache bash nginx openssh jq curl busybox tzdata

# Enable crond service from busybox
RUN mkdir -p /var/spool/cron/crontabs && \
    touch /etc/crontabs/root

# Create necessary directories
RUN mkdir -p /var/www/html /scripts /config /root/.ssh

# Add environment variables for configuration
ENV CRON_SCHEDULE="*/5 * * * *"

# Default timezone is UTC
ENV TZ="UTC"

# Set the timezone dynamically
RUN ln -sf /usr/share/zoneinfo/$TZ /etc/localtime && echo $TZ > /etc/timezone

# Copy the private SSH key to the container
COPY id_rsa /root/.ssh/id_rsa
RUN chmod 600 /root/.ssh/id_rsa

# Copy the Bash script to the container
COPY getservices.sh /scripts/getservices.sh
RUN chmod +x /scripts/getservices.sh

# Add a script to generate the crontab dynamically
RUN echo '#!/bin/sh' > /scripts/init-cron.sh && \
    echo "echo \"\$CRON_SCHEDULE /scripts/getservices.sh > /var/www/html/docker_containers.html\" > /etc/crontabs/root" >> /scripts/init-cron.sh && \
    echo "ln -sf /usr/share/zoneinfo/\$TZ /etc/localtime && echo \$TZ > /etc/timezone" >> /scripts/init-cron.sh && \
    echo "/usr/sbin/nginx -g 'daemon off;' &" >> /scripts/init-cron.sh && \
    echo "/scripts/getservices.sh &" >> /scripts/init-cron.sh && \
    echo "wait" >> /scripts/init-cron.sh && \
    echo "crond -f -L /var/log/cron.log" >> /scripts/init-cron.sh && \
    chmod +x /scripts/init-cron.sh

# Copy NGINX configuration
COPY nginx.conf /etc/nginx/nginx.conf

# Expose port 80 for the web server
EXPOSE 80

# Run the cron initialization script
CMD ["/bin/sh", "/scripts/init-cron.sh"]
