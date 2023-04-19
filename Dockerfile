# Stage 1: Composer
FROM php:8.1.16-fpm-alpine3.16 as composer
# Install necessary dependencies
RUN apk --update --no-cache add git zip unzip
# Install Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

WORKDIR /app
COPY ./ /app

RUN composer install --no-scripts --no-autoloader --no-dev --prefer-dist && \
    rm -rf /root/.composer/cache/*

# Stage 2: Build
# We need a stage which contains FPM to actually run and process requests to our PHP application.
FROM composer as build

EXPOSE 9000
WORKDIR /var/www/html

RUN apk --update --no-cache add \
    bash \
    ca-certificates \
    curl \
    openssl \
    nodejs \
    npm \
    build-base \
    autoconf \
    curl-dev \
    && pecl install mongodb redis \
    && docker-php-ext-enable mongodb redis \
    && pecl config-set php_ini /etc/php.ini \
    && docker-php-ext-install pdo pdo_mysql \
    && rm -rf /var/cache/apk/*

COPY docker/php-fpm/php-ini-overrides.ini $PHP_INI_DIR/conf.d/99-overrides.ini
COPY docker/php-fpm/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
# Copy the rest of your application code to the fpm stage
COPY ./ /var/www/html
COPY --from=composer /app/vendor /var/www/html/vendor

#RUN php artisan storage:link

RUN ln -s /var/www/html/storage/app /var/www/html/public/storage

RUN touch storage/logs/laravel.log

RUN chmod +x /usr/local/bin/docker-entrypoint.sh
RUN chmod -R 777 /var/www/html/storage

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["php-fpm"]

# Stage 3: Cron
# We need a CRON container to the Laravel Scheduler.
# We'll start with the CLI container as our base,
# as we only need to override the CMD which the container starts with to point at cron
# Create a new stage for the cron job
FROM build AS cron

WORKDIR /var/www/html

# Install cron and configure a new cron job
#RUN apk update && \
#    apk add --no-cache cron
# Add the cron job to the crontab file
COPY docker/cron/crontab /etc/cron.d/laravel-cron
# Give execution rights on the cron job
RUN chmod 0644 /etc/cron.d/laravel-cron
# Apply cron job to the crontab
RUN crontab /etc/cron.d/laravel-cron
# Start the cron job and PHP FPM process
CMD crontab -f && php-fpm

# Stage 4: web server (nginx)
# We need an nginx container which can pass requests to our FPM container,
# as well as serve any static content.
FROM nginx as web_server
ADD docker/nginx/nginx.conf /etc/nginx/
ADD docker/nginx/default.conf /etc/nginx/conf.d/
COPY --from=build /var/www/html /usr/share/nginx/html
ADD docker/nginx/ssl/ssl.crt /etc/ssl/certs/ssl.cert
ADD docker/nginx/ssl/ssl.key /etc/ssl/private/ssl.key
WORKDIR /usr/share/nginx/html