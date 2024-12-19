ARG ENV_SOURCE_IMAGE
ARG PHP_VERSION
FROM ${ENV_SOURCE_IMAGE}:${PHP_VERSION} AS spx-builder

USER root
RUN dnf install -y php-devel \
    && dnf clean all \
    && rm -rf /var/cache/dnf

RUN set -eux \
    && cd /tmp \
    && git clone https://github.com/NoiseByNorthwest/php-spx.git \
    && cd php-spx \
    && phpize \
    && ./configure \
    && make \
    && make install

FROM ${ENV_SOURCE_IMAGE}:${PHP_VERSION}
COPY --from=spx-builder /usr/lib64/php/modules/spx.so /usr/lib64/php/modules/spx.so
COPY --from=spx-builder /usr/share/misc/php-spx /usr/share/misc/php-spx
COPY spx/spx.ini /etc/php.d/30-spx.ini

ENV SPX_ENABLED=1
USER www-data
