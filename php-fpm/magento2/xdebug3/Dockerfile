ARG ENV_SOURCE_IMAGE
ARG PHP_VERSION
FROM ${ENV_SOURCE_IMAGE}:${PHP_VERSION}-magento2
ARG PHP_VERSION
USER root

RUN set -eux \
    && dnf install -y php-pecl-xdebug3 \
    && dnf clean all \
    && rm -rf /var/cache/dnf

COPY xdebug3/etc/*.ini /etc/
COPY xdebug3/etc/php.d/* /etc/php.d/

RUN if [[ $(printf "8.0\n${PHP_VERSION}" | sort -h | head -n1) == "8.0" ]]; \
    then mv /etc/php.d/15-xdebug3.2.ini.template /etc/php.d/15-xdebug.ini; \
    else mv /etc/php.d/15-xdebug3.ini.template /etc/php.d/15-xdebug.ini; fi

USER www-data
