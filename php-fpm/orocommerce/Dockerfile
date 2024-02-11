ARG ENV_SOURCE_IMAGE
ARG PHP_VERSION

FROM ${ENV_SOURCE_IMAGE}:${PHP_VERSION}
ARG PHP_EXTENSIONS="pcntl pgsql pdo_pgsql imap tidy ldap pecl-mongodb"

USER root

RUN set -eux \
    && PHP_PACKAGES= && for PKG in ${PHP_EXTENSIONS}; do \
        if [[ ${PKG} = "mcrypt" ]] && (( ${PHP_VERSION} > 71 )); then continue; fi; \
        if [[ ${PKG} = "sodium" ]] && (( ${PHP_VERSION} < 72 )); then continue; fi; \
        PHP_PACKAGES+="php-${PKG} "; \
    done \
    && dnf install -y ${PHP_PACKAGES} jpegoptim pngquant supervisor \
    && dnf clean all \
    && rm -rf /var/cache/dnf \
    && perl -pi -e 's/^(memory_limit)=.*$/$1=2G/g' /etc/php-fpm-fcgi.ini

RUN mkdir -p /var/log/supervisor \
    && chown www-data:www-data /var/log/supervisor

COPY oro-init /usr/local/bin/
COPY etc/php.d/*.ini /etc/php.d/
COPY etc/supervisord.d/* /etc/supervisord.d/

# Inject the oro customization before starting PHP-FPM
RUN sed -i '/^exec "\$@"/i oro-init\n' /usr/local/bin/docker-entrypoint

USER www-data