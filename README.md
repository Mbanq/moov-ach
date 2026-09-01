# moov-ach

Mbanq build of [moov-io/ach](https://github.com/moov-io/ach), published to
`ghcr.io/mbanq/moov-ach`.

## TLS (SRE-8367 / Security Hub ELB.21)

ELB.21 requires ALB/NLB target groups to health check over an encrypted
protocol. The upstream `moov/ach` image serves plain HTTP, so this image bakes
in a self-signed certificate and enables TLS on the application port.

The upstream image is built `FROM scratch` (no shell, no openssl), so the
certificate cannot be generated at container start. It is generated in an
`alpine` builder stage at image build time and copied in, owned by uid/gid
`1000` (the `moov` user the server runs as).

`cmd/server` starts the main listener with `ListenAndServeTLS` when both
`HTTPS_CERT_FILE` and `HTTPS_KEY_FILE` are set, which the Dockerfile does:

| Variable           | Value           |
| ------------------ | --------------- |
| `HTTPS_CERT_FILE`  | `/tls/tls.crt`  |
| `HTTPS_KEY_FILE`   | `/tls/tls.key`  |

### Ports

| Port | Protocol  | Notes                                                |
| ---- | --------- | ---------------------------------------------------- |
| 8080 | **HTTPS** | Application traffic and the `GET /ping` health check. |
| 9090 | HTTP      | Admin/metrics. Upstream serves this in plaintext only. |

Only port 8080 supports TLS, so the target group health check must point at
8080. A health check against 9090 cannot satisfy ELB.21.

### Certificate build args

Defaults are applied unless overridden with `--build-arg`:

| Arg              | Default                                     |
| ---------------- | ------------------------------------------- |
| `TLS_CERT_DAYS`  | `3650`                                      |
| `TLS_CERT_CN`    | `moov-ach`                                  |
| `TLS_CERT_SAN`   | `DNS:moov-ach,DNS:localhost,IP:127.0.0.1`   |

The certificate is self-signed and is not verified by the load balancer, which
encrypts to the target without validating the certificate chain.

### Required target group changes

Enabling TLS changes the wire protocol on 8080, so the target group must be
updated in the same change or traffic will break:

- Protocol: `HTTPS`
- Health check protocol: `HTTPS`
- Health check port: `traffic-port` (8080)
- Health check path: `/ping` (expects `200`, body `PONG`)

### Verifying locally

```sh
docker build -t moov-ach:local .
docker run --rm -p 8080:8080 moov-ach:local

# macOS system curl (LibreSSL) fails against TLS 1.3 here; use a Linux curl:
docker run --rm --network host curlimages/curl -sk https://127.0.0.1:8080/ping
# -> PONG
```
