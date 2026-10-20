# Reference: Caddy mTLS application access

## Components and ports

| Component | Location | Responsibility |
|---|---|---|
| Signing service | One central, SSO-protected server | Issues certificates, records serials, revokes certificates, and produces signed CRLs; it is not reachable from client clusters |
| Distribution relay or deployment job | Separate controlled service/path | Receives signed CA/CRL artifacts from the signing environment and serves or pushes them to client clusters; contains no CA private key |
| SSH service | Each application site | Accepts the user connection to the site's IP and forwards the local browser port to Caddy's loopback listener |
| Caddy | Each application site | Listens on loopback, terminates server TLS, requires/validates client certificates, proxies requests |
| HTTP upstream | Each application site | Serves the app only on `127.0.0.1:8000` (or another loopback/private upstream port); Gunicorn is one example |
| Revocation-list synchronization | Each Caddy site | Obtains the current CRL from the distribution relay (or receives its push) and invokes the selected verifier's update/reload path |

## Files and custody

| File | Permitted location | Notes |
|---|---|---|
| `ca.pem` | Signing server and every Caddy site | Public client-CA certificate |
| `ca.key` | Signing server only | Private key; service-account readable only, mode `0600` |
| `crl.pem` | Signing server, distribution relay, and Caddy sites | Signed revocation data; relay/push it without exposing the signing server |
| Client private key | User device/key store only | Created locally; preferably hardware-backed and non-exportable; never sent to the signing service |
| Client CSR | Enrollment request and signing service | Public-key request submitted through the SSO-protected enrollment flow |
| Issued client certificate and CA chain | User device and signing service registry | Public certificate chain returned by the signing service and bound to the client-held key |
| CA database and issuance registry | Signing server only | Authoritative issuance/revocation state and audit history |

## Baseline Caddyfile

```text
localhost:5059 {
    tls internal {
        client_auth {
            mode require_and_verify
            trust_pool file {
                pem_file /etc/caddy/ca.pem
            }
        }
    }

    reverse_proxy 127.0.0.1:8000 {
        header_up X-Client-CN {tls_client_subject}
    }
}
```

Clients create an SSH forward to the site IP, then browse to the same local
port. For example:

```console
ssh -N -L 5059:127.0.0.1:5059 <ssh-user>@<site-ip>
```

The browser URL is `https://localhost:5059/`; no application DNS name is
required. When `tls internal` is used, clients must trust the corresponding
Caddy server root for `localhost`.

`require_and_verify` requires a presented client certificate and validates its
chain to the configured trust pool. The `{tls_client_subject}` header is set by
Caddy after the TLS handshake; applications must accept this header only from
their loopback Caddy proxy, never from an externally reachable upstream.

The standard Caddy distribution documents the `leaf` client-certificate
verifier. A CRL-capable verifier is not a baseline Caddyfile feature. Verify
the exact modules in the deployed build (for example with `caddy list-modules`)
and use that module's documented configuration. Pin and review any third-party
module before deploying it.

## Issuance record

Record at least these fields for every certificate:

| Field | Purpose |
|---|---|
| `username` | SSO identity that requested issuance |
| `serial` | Unique certificate/revocation lookup key |
| `subject` | Certificate subject; do not use it as the sole authorization source |
| `issue_date`, `expiry_date` | Lifecycle and renewal controls |
| `status` | Active, revoked, expired, or superseded |
| `device/request`, `actor`, `reason` | Audit trail for issuance and revocation |

## OpenSSL CA database and issuance

Initialize the CA database once, as the signing-service account. The database
must be used for issuance as well as revocation; certificates signed only with
`openssl x509 -req` are not entered in `index.txt` automatically.

```console
sudo install -d -m 700 -o signing -g signing /secure/ca-db/newcerts /secure/issued-certs
sudo -u signing touch /secure/ca-db/index.txt
sudo -u signing sh -c 'printf "01\\n" > /secure/ca-db/serial'
sudo -u signing sh -c 'printf "01\\n" > /secure/ca-db/crlnumber'
```

`/secure/openssl.cnf` must at minimum identify the CA key, CA certificate,
database, serial files, and CRL settings. Paths shown here match this guide:

```ini
[ ca ]
default_ca = CA_default

[ CA_default ]
dir             = /secure/ca-db
database        = $dir/index.txt
new_certs_dir   = $dir/newcerts
certificate     = /secure/ca.pem
private_key     = /secure/ca.key
serial          = $dir/serial
crlnumber       = $dir/crlnumber
default_days    = 365
default_crl_days = 30
default_md      = sha256
policy          = policy_any
unique_subject  = no

[ policy_any ]
commonName      = supplied
```

For the required client-generated CSR flow, the SSO-protected handler accepts
only a CSR from the enrollment mechanism, validates that the authenticated SSO
user is allowed to obtain the requested certificate, then issues with the CA
database:

```console
sudo -u signing openssl ca -batch -config /secure/openssl.cnf \
  -in "$REQUEST_CSR" -out "$ISSUED_CERTIFICATE"
```

Read the serial from the issued certificate, store the certificate under a
serial-based path in `/secure/issued-certs/`, and write the registry entry in a
transaction. Return only the signed certificate and CA chain to the enrollment
mechanism. Reject untrusted request fields rather than interpolating them into
paths or shell commands. The handler must obtain the identity and certificate
subject policy from the validated SSO session, not from a CSR subject or a
request parameter.

## Revocation-list synchronization

A CRL is the preferred synchronized artifact: it is signed by the CA, contains
only revoked certificate serials, and does not require replacing valid client
certificates. A custom signed serial deny-list can meet the same requirement
only if its verifier authenticates the artifact, handles stale/failed updates
fail-closed according to policy, and has a revocation test. Do not use a Caddy
leaf allow-list as the normal revocation mechanism; it turns each new issuance
into a fleet configuration deployment.

The signing server is never the download endpoint for a client cluster. It
exports the signed CRL through a one-way publication step to a distribution
relay, or a controlled job pushes the artifact from a management network. The
relay may be reachable from client clusters; it holds neither `ca.key` nor the
CA database. A cluster must not have a route, VPN exception, DNS record, or
credential that lets it contact the signing service.

The updater must download to a temporary file, verify the download, replace
atomically only on change, and invoke the selected verifier's reload/update
path. This example is the Caddy reload variant:

```bash
#!/bin/bash
set -euo pipefail

readonly CRL_URL='https://pki-artifacts.internal/internal-app-client-ca/crl.pem'
readonly CRL_PATH='/etc/caddy/crl.pem'
readonly TMP_PATH="${CRL_PATH}.tmp"

curl --fail --silent --show-error --proto '=https' --tlsv1.2 \
  "$CRL_URL" -o "$TMP_PATH"
openssl crl -in "$TMP_PATH" -noout -verify -CAfile /etc/caddy/ca.pem

if ! cmp -s "$TMP_PATH" "$CRL_PATH" 2>/dev/null; then
  install -m 0644 "$TMP_PATH" "$CRL_PATH"
  rm -f "$TMP_PATH"
  systemctl reload caddy
  logger -t sync-crl 'CRL updated and Caddy reloaded'
else
  rm -f "$TMP_PATH"
fi
```

A 15-minute system cron schedule is `*/15 * * * * /usr/local/bin/sync-crl.sh`.
`pki-artifacts.internal` is an example distribution relay, not the signing
server. Protect relay transport with normal server TLS validation (and
preferably restrict it to site hosts); never use `curl --insecure`. A
relay-initiated push is the alternative when clusters cannot pull even from the
relay.

## Verification criteria

- Caddy configuration passes `caddy validate` before reload.
- A valid client certificate is accepted and an absent/untrusted certificate is
  rejected at TLS handshake time.
- The HTTP upstream is unreachable from non-loopback interfaces.
- The app receives the expected authenticated identity only through Caddy.
- After CRL deployment, a revoked test certificate is rejected within the
  documented propagation objective.
