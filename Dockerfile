FROM php:7.4-apache as builder

RUN mkdir -p /tmp/app
WORKDIR /tmp/app

RUN apt update

RUN apt dist-upgrade -y

RUN apt install --yes \
    gcc make autoconf libc-dev pkg-config libzip-dev \
    bash \
    curl \
    git \
    ca-certificates \
    libpng-dev \
    icu-devtools \
    libicu-dev \
    cron \
    wget \
    openssl \
    unzip \
    iputils-ping \
    gettext \
    libxml2-dev \
    sqlite3 \
    libsqlite3-dev \
    bash-completion \
    nano

RUN docker-php-ext-install gettext && docker-php-ext-enable gettext
RUN docker-php-ext-install pdo_mysql && docker-php-ext-enable pdo_mysql
RUN docker-php-ext-install pdo_sqlite && docker-php-ext-enable pdo_sqlite
RUN docker-php-ext-install zip && docker-php-ext-enable zip
RUN docker-php-ext-install json && docker-php-ext-enable json
RUN docker-php-ext-install xml && docker-php-ext-enable xml
RUN docker-php-ext-install opcache && docker-php-ext-enable opcache
RUN pecl install -f xdebug
RUN docker-php-ext-enable xdebug
RUN docker-php-ext-configure gd
RUN NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) && \
  docker-php-ext-install -j$(nproc) gd && docker-php-ext-enable gd
RUN docker-php-ext-configure intl
RUN NPROC=$(grep -c ^processor /proc/cpuinfo 2>/dev/null || 1) && \
  docker-php-ext-install -j$(nproc) intl && docker-php-ext-enable intl

RUN a2enmod headers
RUN a2enmod rewrite

RUN curl https://raw.githubusercontent.com/docker/docker-ce/master/components/cli/contrib/completion/bash/docker -o /etc/bash_completion.d/docker.sh

RUN git clone https://github.com/rantes/DumboPHP.git .
RUN ln -s /usr/local/bin/php /usr/bin/php
RUN chmod +x ./install.php
RUN ./install.php

COPY php.ini-production /usr/local/etc/php/php.ini

FROM builder as release

RUN usermod -u 1000 www-data \
 && groupmod -g 1000 www-data

RUN mkdir -p /var/www/html
WORKDIR /var/www/html
COPY --chown=www-data . .
RUN chown -R www-data:www-data /var/www/html

USER www-data

EXPOSE 80
