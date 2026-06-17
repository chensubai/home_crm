FROM composer:2 AS vendor

WORKDIR /app
COPY composer.json composer.lock* ./
RUN composer install --no-interaction --prefer-dist --no-scripts

FROM php:8.4-fpm-alpine

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN apk add --no-cache oniguruma-dev sqlite-dev \
    && docker-php-ext-install mbstring pdo_mysql pdo_sqlite

WORKDIR /var/www/html
COPY --from=vendor /app/vendor ./vendor
COPY . .
COPY docker/php/entrypoint.sh /usr/local/bin/operations-home-entrypoint

RUN chmod +x /usr/local/bin/operations-home-entrypoint \
    && chown -R www-data:www-data storage bootstrap/cache

ENTRYPOINT ["operations-home-entrypoint"]
CMD ["php-fpm"]
