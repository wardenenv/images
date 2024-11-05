ARG CADDY_NGROK_VERSION=${CADDY_NGROK_VERSION:-2.7}
FROM caddy:${CADDY_NGROK_VERSION:-2.7}-builder AS builder

RUN xcaddy build \
    --with github.com/caddyserver/replace-response

FROM caddy:${CADDY_NGROK_VERSION}

COPY --from=builder /usr/bin/caddy /usr/bin/caddy
