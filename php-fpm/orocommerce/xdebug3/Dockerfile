ARG ENV_SOURCE_IMAGE="ghcr.io/wardenenv/php-fpm"
ARG PHP_VERSION="8.4"
FROM ${ENV_SOURCE_IMAGE}:${PHP_VERSION}-orocommerce
USER root

COPY *.ini /etc/php.d/

USER www-data