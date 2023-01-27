ARG ENV_SOURCE_IMAGE
ARG PHP_VERSION
ARG OS_RELEASE

FROM golang:alpine AS mhs-builder
RUN go install github.com/mailhog/mhsendmail@latest


FROM ${ENV_SOURCE_IMAGE:-php}:${PHP_VERSION}-fpm-${OS_RELEASE:-bullseye}
USER root
ARG PHP_VERSION

ENV MAILHOG_HOST    mailhog
ENV MAILHOG_PORT    1025
ENV USER_ID         501
ENV GROUP_ID        20
ENV OSTYPE          darwin220

# PHP Extension Installer
ADD https://github.com/mlocati/docker-php-extension-installer/releases/latest/download/install-php-extensions /usr/local/bin/

# Copy mhsendmail to PHP
COPY --from=mhs-builder /go/bin/mhsendmail /usr/local/bin/mhsendmail

# Install PHP Extensions required by Magento OS, Adobe Commerce, and the UCT (pcntl)
RUN chmod +x /usr/local/bin/install-php-extensions && install-php-extensions \
    apcu \
    amqp \
    bcmath \
    calendar \
    exif \
    gd \
    intl \
    imagick \
    imap \
    mcrypt \
    mysqli \
    pcntl \
    pdo_mysql \
    redis \
    soap \
    sockets \
    sodium \
    xsl \
    zip

# Install helpful utilities
RUN set -eux; \
    apt-get update -y; \
    apt-get install -y --no-install-recommends \
    jq \
    bash \
    patch \
    pv \
    procps \
    nano \
    vim \
    mariadb-client \
    sudo \
    gettext \
    ca-certificates \
    git \
    rsync \
    bash-completion \
    nmap  \
    less \
    zsh \
    fish \
    pwgen \
    openssh-client \
    unzip \
    rsync \
    socat \
    oathtool \
    wget \
    ack  \
    automake  \
    autoconf \
    python \
    cron \
    htop \
    chromium \
    imagemagick \
    graphicsmagick; \
    apt-get clean; \
    rm -rf /var/lib/apt/lists/*

COPY docker-entrypoint /usr/local/bin/
COPY etc/profile.d/*.sh /etc/profile.d/
COPY etc/php.d/*.ini /usr/local/etc/php/conf.d
COPY etc/php.d/05-additions.ini.template /usr/local/etc/php/conf.d

RUN set -eux \
    && cp ${PHP_INI_DIR}/php.ini-development ${PHP_INI_DIR}/php.ini \
    && perl -pi -e 's/memory_limit(.*)/memory_limit=-1/g' ${PHP_INI_DIR}/php.ini

# Install Composer
COPY --from=composer:1 /usr/bin/composer /usr/bin/composer1
COPY --from=composer:2.2 /usr/bin/composer /usr/bin/composer2lts
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer2

# If PHP < 7.2
RUN if [ "$(printf "7.2\n${PHP_VERSION}" | sort -g | head -n1)" != "7.2" ]; \
    then mv -f /usr/bin/composer2lts /usr/bin/composer2; fi

# If PHP < 7.3
RUN if [ "$(printf "7.3\n${PHP_VERSION}" | sort -g | head -n1)" != "7.3" ]; \
    then apt-get install -y --no-install-recommends bind9utils; fi

# If PHP >= 7.1
RUN if [ "$(printf "7.1\n${PHP_VERSION}" | sort -g | head -n1)" = "7.1" ]; \
    then apt-get install -y --no-install-recommends libmariadb3 libmariadb-dev \
    && sed -i '/disable ghostscript format types/,+6d' /etc/ImageMagick-6/policy.xml; fi

# If PHP >= 7.3
RUN if [ "$(printf "7.3\n${PHP_VERSION}" | sort -g | head -n1)" = "7.3" ]; \
    then apt-get install -y --no-install-recommends bind9-utils; fi

RUN mkdir -p /etc/zsh/zshrc.d  \
    && echo "autoload -U compinit; compinit" > /etc/zsh/zshrc.d/completions.zsh \
    && ln -s /usr/bin/fish /bin/fish

RUN set -eux; \
	{ \
		echo 'if [ -d /etc/profile.d ]; then'; \
        echo '  for i in /etc/profile.d/*.sh; do'; \
        echo '    if [ -r $i ]; then'; \
        echo '      . $i'; \
        echo '    fi'; \
        echo '  done'; \
        echo '  unset i'; \
        echo 'fi'; \
	} >> /etc/bash.bashrc;

# Install Oh My Zsh including the following Plugins: git, composer and n98-magerun
RUN sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
RUN git clone https://github.com/zsh-users/zsh-autosuggestions.git $ZSH_CUSTOM/plugins/zsh-autosuggestions \
    && git clone https://github.com/zsh-users/zsh-syntax-highlighting.git $ZSH_CUSTOM/plugins/zsh-syntax-highlighting \
    && sed -i 's/plugins=(git)/plugins=(git composer n98-magerun zsh-autosuggestions zsh-syntax-highlighting)/g' /root/.zshrc

# Configure www-data user as primary php-fpm user for better local dev experience
RUN mkdir -p /home/www-data \
    && chown www-data:www-data /home/www-data \
    && usermod -d /home/www-data www-data \
    && install -d -m 0755 -o www-data -g www-data /home/www-data \
    && chmod 0755 ~www-data \
    && mkdir -p /var/www/html \
    && chown www-data:www-data /var/www/html \
    && echo "www-data ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/nopasswd

STOPSIGNAL SIGQUIT

ENTRYPOINT ["docker-entrypoint"]
WORKDIR /var/www/html
USER www-data
EXPOSE 9000
CMD ["php-fpm"]
