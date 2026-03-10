# Coolify official option: Dockerfile + Nginx Unit (port 8000)
# See: https://coolify.io/docs/applications/laravel#deploy-with-dockerfile-and-nginx-unit
# In Coolify: set Ports Exposes to 8000 and use this file as Dockerfile (or build with docker build -f Dockerfile.unit).

FROM php:8.5-cli-alpine AS vendor
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
WORKDIR /app
COPY composer.json composer.lock ./
RUN composer install --no-dev --optimize-autoloader --no-scripts --no-interaction --ignore-platform-reqs

FROM oven/bun:1-alpine AS frontend
WORKDIR /app
COPY package.json bun.lock* ./
RUN bun install --frozen-lockfile
COPY --from=vendor /app/vendor ./vendor
COPY resources resources
COPY vite.config.js ./
COPY public public
RUN bun run build

# Unit does not yet publish php8.5; use 8.4 until unit:php8.5 is available
FROM unit:1.34.1-php8.4 AS base

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl unzip git libicu-dev libzip-dev libpng-dev libjpeg-dev libfreetype6-dev libpq-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install -j$(nproc) pcntl opcache pdo pdo_pgsql intl zip gd exif bcmath \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN { echo "opcache.enable=1"; echo "opcache.jit=tracing"; echo "opcache.jit_buffer_size=256M"; \
     echo "memory_limit=512M"; echo "upload_max_filesize=64M"; echo "post_max_size=64M"; } \
    > /usr/local/etc/php/conf.d/99-custom.ini

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

WORKDIR /var/www/html

RUN mkdir -p storage/framework/cache storage/framework/sessions storage/framework/views storage/logs bootstrap/cache

COPY composer.json composer.lock ./
RUN composer install --prefer-dist --optimize-autoloader --no-dev --no-interaction --no-scripts

COPY . .
COPY --from=frontend /app/public/build /var/www/html/public/build

RUN chown -R unit:unit /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

COPY unit.json /docker-entrypoint.d/unit.json

EXPOSE 8000

CMD ["unitd", "--no-daemon"]
