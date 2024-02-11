ARG POSTGRES_VERSION=15.1

FROM postgres:${POSTGRES_VERSION}

COPY ./docker-entrypoint-initdb.d/add-uuid-ossp-extension.sql /docker-entrypoint-initdb.d/add-uuid-ossp-extension.sql
