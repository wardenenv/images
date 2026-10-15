ARG MARIADB_VERSION
FROM mariadb:${MARIADB_VERSION:-lts}

SHELL [ "/usr/bin/env", "bash", "-c" ]

RUN <<EOF
    # Drop package epoch prefix (e.g. `1:`) if there is one
    ver="${MARIADB_VERSION#*:}"
    # Include mysql compatible commands for mariadb > 11 since it was deprecated / dropped
    if [[ ${ver%%.*} >= 11 ]]; then
        apt-get update
        apt-get install -y mariadb-server-compat mariadb-client-compat
        rm -rf /var/lib/apt/lists/*
    fi
EOF
