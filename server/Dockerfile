FROM composer:2 AS vendor

WORKDIR /app
COPY composer.json composer.lock* ./
RUN composer install --no-interaction --prefer-dist --no-scripts

FROM php:8.4-fpm-alpine

COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

RUN apk add --no-cache oniguruma-dev sqlite-dev libjpeg-turbo-dev libpng-dev freetype-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install gd mbstring pdo_mysql pdo_sqlite

WORKDIR /var/www/html
COPY --from=vendor /app/vendor ./vendor
COPY . .
COPY docker/php/entrypoint.sh /usr/local/bin/operations-home-entrypoint
COPY docker/php/uploads.ini /usr/local/etc/php/conf.d/uploads.ini

RUN chmod +x /usr/local/bin/operations-home-entrypoint \
    && chown -R www-data:www-data storage bootstrap/cache

ENTRYPOINT ["operations-home-entrypoint"]
CMD ["php-fpm"]
