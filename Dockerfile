FROM php:7.4-apache as builder

WORKDIR /tmp

RUN apt update

RUN apt install --yes \
    gcc make autoconf libc-dev pkg-config libzip-dev \
    bash \
    curl \
    git \
    ca-certificates \
    wget \
    openssl \
    unzip \
    iputils-ping \
    gettext \
    nano

RUN docker-php-ext-install gettext && docker-php-ext-enable gettext
RUN docker-php-ext-install pdo_mysql && docker-php-ext-enable pdo_mysql
RUN docker-php-ext-install zip && docker-php-ext-enable zip
RUN docker-php-ext-install json && docker-php-ext-enable json
RUN pecl install -f xdebug
RUN docker-php-ext-enable xdebug

RUN curl -sL https://getcomposer.org/installer | php -- --install-dir /usr/bin --filename composer \
    && composer clear-cache

COPY config/php-fpm.ini /usr/local/etc/php/conf.d/local.ini

FROM php:7.4-apache as dependencies

WORKDIR /tmp

RUN curl -sL https://getcomposer.org/installer | php -- --install-dir /usr/bin --filename composer \
    && composer clear-cache

COPY composer.json .
COPY docker-startup.sh .

RUN mkdir -p tmp/logs

RUN composer install \
    --no-ansi \
    --no-autoloader \
    --no-interaction \
    --no-scripts

RUN composer update
COPY . .

RUN composer dump-autoload

FROM builder as release

RUN mkdir -p /var/www/html
WORKDIR /var/www/html
COPY --chown=www-data --from=dependencies /tmp .

USER www-data

RUN echo 'Running migrations...'
RUN php dumbo migration run all
RUN echo 'Running sowing seeds...'
RUN php dumbo migration sow
# Validate integrations like database
RUN echo 'Running test integrations (also database)...'
RUN ls -ahl
RUN php -d xdebug.mode=coverage,profile dumboTest all --dir=tests/integrations
RUN echo 'Sync translations...'
RUN php dumbo run background/gettext
RUN echo 'Running unit tests...'
RUN php -d xdebug.mode=coverage,profile dumboTest all

EXPOSE 80
