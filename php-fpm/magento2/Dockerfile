ARG ENV_SOURCE_IMAGE="ghcr.io/wardenenv/php-fpm"
ARG PHP_VERSION="8.4"
FROM ${ENV_SOURCE_IMAGE}:${PHP_VERSION}
USER root

RUN npm install -g grunt-cli gulp yarn

RUN set -eux \
    && PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2 | awk -F '.' '{print $1$2}') \
    && if (( ${PHP_VERSION} < 80 )); \
        then MAGERUN_PHAR_URL=https://files.magerun.net/n98-magerun2-7.5.0.phar; \
        else MAGERUN_PHAR_URL=https://files.magerun.net/n98-magerun2.phar; \
    fi \
    && mkdir -p /usr/local/bin \
    && curl -s ${MAGERUN_PHAR_URL} > /usr/local/bin/n98-magerun \
    && chmod +x /usr/local/bin/n98-magerun

RUN set -eux \
    && PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2 | awk -F '.' '{print $1$2}') \
    && if (( ${PHP_VERSION} < 80 )); \
        then MAGERUN_BASH_REF=7.5.0; \
        else MAGERUN_BASH_REF=master;\
    fi \
    && curl -o /etc/bash_completion.d/n98-magerun2.phar.bash \
        https://raw.githubusercontent.com/netz98/n98-magerun2/${MAGERUN_BASH_REF}/res/autocompletion/bash/n98-magerun2.phar.bash \
    && perl -pi -e 's/^(complete -o default .*)$/$1 n98-magerun/' /etc/bash_completion.d/n98-magerun2.phar.bash

# Create mr alias for n98-magerun
RUN ln -s /usr/local/bin/n98-magerun /usr/local/bin/mr

USER www-data
