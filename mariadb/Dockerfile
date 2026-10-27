ARG MARIADB_VERSION
FROM mariadb:${MARIADB_VERSION:-lts}

SHELL [ "/usr/bin/env", "bash", "-c" ]

RUN <<EOF
    if [[ ${MARIADB_VERSION} =~ ^1:11 ]]; then
        apt-get update
        apt-get install -y mariadb-server-compat mariadb-client-compat
        rm -rf /var/lib/apt/lists/*
    fi
EOF
