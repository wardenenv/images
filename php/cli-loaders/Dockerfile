ARG IMAGE_NAME="davidalger/php"
ARG PHP_VERSION
FROM ${IMAGE_NAME}:${PHP_VERSION}

# Install and enable Source Gaurdian loader
RUN PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2 | cut -d. -f1-2) \
    && mkdir -p /tmp/sourceguardian \
    && cd /tmp/sourceguardian \
    && curl -Os https://www.sourceguardian.com/loaders/download/loaders.linux-x86_64.tar.gz \
    && tar xzf loaders.linux-x86_64.tar.gz \
    && SOURCEGUARDIAN_LOADER_PATH=ixed.${PHP_VERSION}.lin \
    && if [[ -f ${SOURCEGUARDIAN_LOADER_PATH} ]]; then \
        cp ${SOURCEGUARDIAN_LOADER_PATH} "$(php -i | grep '^extension_dir =' | cut -d' ' -f3)/sourceguardian.so" \
            && echo "extension=sourceguardian.so" > /etc/php.d/15-sourceguardian.ini; \
    else \
        >&2 printf "\033[33mWARNING\033[0m: Source Gaurdian loaders for PHP_VERSION %s could not be found at %s\n" \
            "${PHP_VERSION}" "${SOURCEGUARDIAN_LOADER_PATH}"; \
    fi \
    && rm -rf /tmp/sourceguardian

# Install and enable IonCube loader
RUN PHP_VERSION=$(php -v | head -n1 | cut -d' ' -f2 | cut -d. -f1-2) \
    && mkdir -p /tmp/ioncube \
    && cd /tmp/ioncube \
    && curl -Os https://downloads.ioncube.com/loader_downloads/ioncube_loaders_lin_x86-64.tar.gz \
    && tar xzf ioncube_loaders_lin_x86-64.tar.gz \
    && IONCUBE_LOADER_PATH=ioncube/ioncube_loader_lin_${PHP_VERSION}.so \
    && if [[ -f ${IONCUBE_LOADER_PATH} ]]; then \
        cp ${IONCUBE_LOADER_PATH} "$(php -i | grep '^extension_dir =' | cut -d' ' -f3)/ioncube_loader.so" \
            && echo "zend_extension=ioncube_loader.so" > /etc/php.d/01-ioncube-loader.ini; \
    else \
        >&2 printf "\033[33mWARNING\033[0m: IonCube loaders for PHP_VERSION %s could not be found at %s\n" \
            "${PHP_VERSION}" "${IONCUBE_LOADER_PATH}"; \
    fi \
    && rm -rf /tmp/ioncube
