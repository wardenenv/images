ARG ENV_SOURCE_IMAGE
ARG PHP_VERSION
FROM ${ENV_SOURCE_IMAGE}:${PHP_VERSION}
USER root

RUN npm install -g grunt-cli gulp yarn

RUN set -eux \
    && PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2 | awk -F '.' '{print $1$2}') \
    && mkdir -p /usr/local/bin \
    && curl -O https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar /usr/local/bin/wp-cli \
    && chmod +x /usr/local/bin/wp-cli

RUN set -eux \
    && PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2 | awk -F '.' '{print $1$2}') \
    && curl -o /etc/bash_completion.d/wp-completion.bash \
        https://raw.githubusercontent.com/wp-cli/wp-cli/v2.10.0/utils/wp-completion.bash

# Create wp alias for wp-cli
RUN ln -s /usr/local/bin/wp-cli /usr/local/bin/wp

USER www-data
