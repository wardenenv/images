ARG ENV_SOURCE_IMAGE="ghcr.io/wardenenv/php-fpm"
ARG PHP_VERSION="8.4"

FROM ${ENV_SOURCE_IMAGE}:${PHP_VERSION}-orocommerce
USER root

RUN set -eux \
    && dnf install -y php-pecl-xdebug3 \
    && dnf clean all \
    && rm -rf /var/cache/dnf

COPY etc/*.ini /etc/
COPY etc/php.d/*.ini /etc/php.d/

USER www-data