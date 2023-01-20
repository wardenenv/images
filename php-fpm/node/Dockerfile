ARG ENV_SOURCE_IMAGE
ARG PHP_VERSION
ARG OS_RELEASE
ARG NODE_VERSION

FROM node:${NODE_VERSION}-${OS_RELEASE:-bullseye} AS node
RUN npm install -g grunt-cli gulp
RUN mv /opt/yarn* /opt/yarn

FROM ${ENV_SOURCE_IMAGE}:${PHP_VERSION}
USER root

# Copy Node to PHP
COPY --from=node /usr/local/include/node /usr/local/include/node
COPY --from=node /usr/local/lib/node_modules /usr/local/lib/node_modules
COPY --from=node /opt /opt
COPY --from=node /usr/local/bin/node /usr/local/bin/node

# Copy PhantomJS
COPY --from=99designs/phantomjs:2.1.1 /usr/local/bin/phantomjs /usr/local/bin/phantomjs

RUN ln -s /usr/local/bin/node /usr/local/bin/nodejs \
    && ln -s /usr/local/lib/node_modules/npm/bin/npm-cli.js /usr/local/bin/npm \
    && ln -s /usr/local/lib/node_modules/gulp/bin/gulp.js /usr/local/bin/gulp \
    && ln -s /usr/local/lib/node_modules/grunt-cli/bin/grunt /usr/local/bin/grunt \
    && ln -s /usr/local/lib/node_modules/npm/bin/npx-cli.js /usr/local/bin/npx \
    && ln -s /opt/yarn/bin/yarn /usr/local/bin/yarn \
    && ln -s /opt/yarn/bin/yarnpkg /usr/local/bin/yarnpkg

# Copy Yarn
COPY --from=node /opt /opt

USER www-data
