ARG ENV_SOURCE_IMAGE
ARG PHP_VERSION
FROM ${ENV_SOURCE_IMAGE}:${PHP_VERSION}
USER root

# Wordpress Cli tool
ADD https://raw.githubusercontent.com/wp-cli/builds/gh-pages/phar/wp-cli.phar /usr/local/bin/wp-cli

# Create wp alias for wp-cli
RUN chmod +rx /usr/local/bin/wp-cli \
    && ln -s /usr/local/bin/wp-cli /usr/local/bin/wp

USER www-data