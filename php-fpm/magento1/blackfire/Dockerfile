ARG ENV_SOURCE_IMAGE="ghcr.io/wardenenv/php-fpm"
ARG PHP_VERSION="8.4"

FROM ${ENV_SOURCE_IMAGE}:${PHP_VERSION}
USER root

RUN curl -o - "http://packages.blackfire.io/fedora/blackfire.repo" \
    | tee /etc/yum.repos.d/blackfire.repo \
    && dnf install -y blackfire blackfire-php \
    && dnf clean all \
    && rm -rf /var/cache/dnf

COPY etc/php.d/*.ini /etc/php.d/

USER www-data
