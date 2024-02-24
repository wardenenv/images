ARG POSTGRES_VERSION
FROM postgres:${POSTGRES_VERSION}

COPY docker-entrypoint-initdb.d/uuid-ossp-extension.sql /docker-entrypoint-init.d/uuid-ossp-extension.sql

