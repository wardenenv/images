FROM quay.io/centos/centos:stream9

ARG PHP_VERSION
ARG PHP_EXTENSIONS="bcmath cli common gd gmp intl json mbstring \
    mcrypt sodium mysqlnd pgsql opcache pdo pdo_pgsql pecl-msgpack pecl-amqp pecl-redis pecl-imagick pecl-zip pecl-swoole process soap xml xmlrpc"
ARG COMPOSER_VERSION=2

RUN dnf update -y \
    && dnf clean all \
    && rm -rf /var/cache/dnf

RUN set -eux \
    && dnf install -y epel-release \
    && dnf install -y https://rpms.remirepo.net/enterprise/remi-release-9.rpm \
    && dnf module reset php -y \
    && dnf module install -y php:remi-${PHP_VERSION} \
    && PHP_VERSION=$(echo ${PHP_VERSION} | awk -F '.' '{print $1$2}') \
    && PHP_PACKAGES= && for PKG in ${PHP_EXTENSIONS}; do \
        if [[ ${PKG} = "mcrypt" ]] && (( ${PHP_VERSION} > 71 )); then continue; fi; \
        if [[ ${PKG} = "sodium" ]] && (( ${PHP_VERSION} < 72 )); then continue; fi; \
        if [[ ${PKG} = "xmlrpc" ]] && (( ${PHP_VERSION} > 83 )); then continue; fi; \
        PHP_PACKAGES+="php-${PKG} "; \
    done \
    && dnf install -y ${PHP_PACKAGES} git perl which npm patch gettext unzip bzip2 pwgen procps nmap-ncat jq \
    && dnf clean all \
    && rm -rf /var/cache/dnf

RUN set -eux \
    && cp /etc/php.ini /etc/php-cli.ini \
    && perl -pi -e 's/memory_limit(.*)/memory_limit=-1/g' /etc/php-cli.ini

ENV COMPOSER_ALLOW_SUPERUSER=1
ENV COMPOSER_HOME=/tmp/composer
COPY --from=composer:1 /usr/bin/composer /usr/bin/composer1
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer2
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer2lts
