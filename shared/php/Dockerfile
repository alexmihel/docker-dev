FROM php:8.2-fpm

# Установка зависимостей и расширений
RUN apt-get update && apt-get install -y \
    git unzip libpq-dev supervisor mc \
    libzip-dev libpng-dev libjpeg-dev libfreetype6-dev \
    && docker-php-ext-configure gd --with-freetype --with-jpeg \
    && docker-php-ext-install \
        pdo \
        pdo_pgsql \
        bcmath \
        zip \
        gd \
        exif \
    && pecl install redis xdebug \
    && docker-php-ext-enable redis xdebug exif

# Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

COPY conf.d/xdebug.ini /usr/local/etc/php/conf.d/99-xdebug.ini

COPY php-fpm.d/zz-env.conf /usr/local/etc/php-fpm.d/zz-env.conf

WORKDIR /var/www/html