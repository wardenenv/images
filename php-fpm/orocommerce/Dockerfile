ARG ENV_SOURCE_IMAGE
ARG PHP_VERSION

FROM ${ENV_SOURCE_IMAGE}:${PHP_VERSION}
ARG PHP_EXTENSIONS="pcntl imap tidy ldap pecl-mongodb"

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
    && perl -pi -e 's/^(memory_limit)=.*$/$1=1G/g' /etc/php-fpm-fcgi.ini \
    && perl -pi -e 's/^(realpath_cache_size)=.*$/$1=4096K/g' /etc/php-fpm-fcgi.ini \
    && perl -pi -e 's/^(realpath_cache_ttl)=.*$/$1=600/g' /etc/php-fpm-fcgi.ini \
    && perl -pi -e 's/^(opcache\.enable)=.*$/$1=1/g' /etc/php.d/10-opcache.ini \
    && perl -pi -e 's/^(opcache\.enable_cli)=.*$/$1=0/g' /etc/php.d/10-opcache.ini \
    && perl -pi -e 's/^(opcache\.memory_consumption)=.*$/$1=512/g' /etc/php.d/10-opcache.ini \
    && perl -pi -e 's/^(opcache\.interned_strings_buffer)=.*$/$1=32/g' /etc/php.d/10-opcache.ini \
    && perl -pi -e 's/^(opcache\.max_accelerated_files)=.*$/$1=32531/g' /etc/php.d/10-opcache.ini \
    && perl -pi -e 's/^(opcache\.save_comments)=.*$/$1=1/g' /etc/php.d/10-opcache.ini

RUN mkdir -p /var/log/supervisor \
    && chown www-data:www-data /var/log/supervisor

COPY oro-init /usr/local/bin/
COPY etc/php.d/*.ini /etc/php.d/
COPY etc/supervisord.d/* /etc/supervisord.d/

# Disabling Phar extension
RUN sed 's/^\(extension=phar\)/;\1/' /etc/php.d/*-phar.ini

# Inject the oro customization before starting PHP-FPM
RUN sed -i '/^exec "\$@"/i oro-init\n' /usr/local/bin/docker-entrypoint

USER www-data
