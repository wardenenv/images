ARG ENV_SOURCE_IMAGE
ARG PHP_VERSION
FROM ${ENV_SOURCE_IMAGE}:${PHP_VERSION}
ARG XDEBUG_TYPE="xdebug-stable"

USER root

RUN export PHP_INI_DIR="/usr/local/etc/php"; install-php-extensions ${XDEBUG_TYPE}

COPY xdebug3/etc/*.ini /usr/local/etc/php/
COPY xdebug3/etc/conf.d/* /usr/local/etc/php/conf.d/

USER www-data
