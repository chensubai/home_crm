#!/bin/sh
set -e

if [ ! -f vendor/autoload.php ]; then
    composer install --no-interaction --prefer-dist --no-scripts
fi

exec docker-php-entrypoint "$@"
