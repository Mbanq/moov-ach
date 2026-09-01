ARG MOOV_ACH_VERSION=v1.42.1

# ---------------------------------------------------------------------------
# Stage 1: generate a self-signed TLS certificate.
#
# The upstream moov/ach image is built FROM scratch, so it has no shell and no
# openssl -- the certificate cannot be generated at container start and must be
# baked in here instead.
# ---------------------------------------------------------------------------
FROM alpine:3.21 AS certgen

ARG TLS_CERT_DAYS=3650
ARG TLS_CERT_CN=moov-ach
ARG TLS_CERT_SAN="DNS:moov-ach,DNS:localhost,IP:127.0.0.1"

RUN apk add --no-cache openssl \
 && mkdir -p /tls \
 && openssl req -x509 -nodes -newkey rsa:2048 \
      -keyout /tls/tls.key \
      -out /tls/tls.crt \
      -days "${TLS_CERT_DAYS}" \
      -subj "/CN=${TLS_CERT_CN}" \
      -addext "subjectAltName=${TLS_CERT_SAN}" \
      -addext "basicConstraints=critical,CA:FALSE" \
      -addext "keyUsage=critical,digitalSignature,keyEncipherment" \
      -addext "extendedKeyUsage=serverAuth" \
 && chmod 0644 /tls/tls.crt \
 && chmod 0600 /tls/tls.key

# ---------------------------------------------------------------------------
# Stage 2: the ACH server, serving HTTPS on 8080.
# ---------------------------------------------------------------------------
FROM moov/ach:${MOOV_ACH_VERSION}

LABEL maintainer="Mbanq dev@mbanq.com"

# uid/gid 1000 is the "moov" user the upstream image runs as.
COPY --from=certgen --chown=1000:1000 /tls/ /tls/

# Picked up by cmd/server: when both are set the main HTTP server is started
# with ListenAndServeTLS (TLS 1.2 minimum) instead of plain HTTP.
ENV HTTPS_CERT_FILE=/tls/tls.crt \
    HTTPS_KEY_FILE=/tls/tls.key

EXPOSE 8080
EXPOSE 9090
