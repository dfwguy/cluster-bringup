# Tutorial: deploy one Caddy-protected HTTP service

By the end of this tutorial, an HTTP application is reachable only through Caddy,
and Caddy requires a valid personal certificate issued by the central client
CA. This tutorial establishes CA-based authentication first; add tested,
serial-based revocation enforcement before relying on revocation.

Gunicorn is the example upstream in the commands below. Substitute any HTTP
service and its loopback listener address where appropriate.

**You will need**

- A signing server protected by the organization's SSO, with an approved CA
  operating procedure.
- A separate revocation-artifact distribution relay or controlled deployment
  path that client clusters can reach. It must not be the signing server.
- A Caddy host and an HTTP application host at the same site (they may be the
  same host).
- SSH access to the site's IP address and authorization to create a local port
  forward.
- Either a server certificate trusted by clients or a plan to distribute the
  Caddy internal root certificate for `localhost`.
- An approved client enrollment mechanism for Windows, macOS, and Linux that
  generates a device-local key, submits a CSR, and installs the returned
  certificate in that same key store.
- A verified Caddy build and a chosen local revocation-list enforcement design.

## 1. Create and protect the client CA

On the signing server only, create the CA. Store the private key outside the
web root and restrict it to the signing-service account.

```console
sudo install -d -m 700 -o signing -g signing /secure
sudo -u signing openssl req -x509 -new -nodes \
  -newkey ec -pkeyopt ec_paramgen_curve:P-256 \
  -keyout /secure/ca.key -sha256 -days 3650 \
  -out /secure/ca.pem -subj "/CN=Internal App Client CA"
sudo chmod 600 /secure/ca.key
```

`ca.pem` is public and may be copied to Caddy hosts. `ca.key` must never leave
the signing server, be placed in source control, or be exposed by the signing
web service.

Use an OpenSSL CA database from the first issuance. It is the authoritative
source needed to revoke and generate CRLs; a separate CSV alone cannot make
`openssl ca -revoke` work.

## 2. Bind the HTTP upstream to loopback

Configure the upstream service to bind only to the local host. For example,
Gunicorn can use:

```console
gunicorn --bind 127.0.0.1:8000 myapp:wsgi
```

Do not expose the upstream port through a firewall, load balancer, or
host-networked container. Otherwise callers could bypass Caddy's
client-certificate check.

## 3. Install the client CA and configure Caddy

Copy `/secure/ca.pem` to `/etc/caddy/ca.pem` with normal readable permissions.
Create a Caddyfile that listens only on the site host's loopback interface.
The client reaches this listener through SSH, so the application has no DNS
name. `localhost:5059` is an example; use a different port when the host
serves more than one application.

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

For a server certificate from an existing trusted internal CA, replace `tls
internal` with `tls /path/to/server.pem /path/to/server.key` while retaining
the `client_auth` block. Its certificate must be valid for `localhost` because
that is the URL the browser uses after forwarding. The server TLS certificate
and the client CA are different trust systems.

Validate before loading the configuration:

```console
sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
sudo systemctl reload caddy
```

## 4. Enroll one client certificate

This design requires a client-generated CSR. The approved enrollment mechanism
creates the private key in the device's user or hardware-backed key store,
then submits only the CSR to the SSO-protected signing service. The service
derives the user from the validated SSO session, validates policy, issues a
certificate with a unique serial, records its username, serial, issue and
expiry dates, and returns the public certificate chain. The enrollment
mechanism installs that certificate against the pre-existing private key.

The signing service must never receive the private key or create a PFX. Have
the user follow [Enroll a client certificate](how-to/install-client-certificate.md).

## 5. Verify the boundary

From a device with the client certificate installed, create the tunnel to the
site IP address and leave it running:

```console
ssh -N -L 5059:127.0.0.1:5059 <ssh-user>@<site-ip>
```

Browse to `https://localhost:5059/` and confirm that Caddy requests or selects
the certificate and that the application receives the intended identity. Also
test through the same tunnel (substitute the approved Caddy server root when
using `tls internal`). The following command is only a lab check for an
exportable test key; normal hardware-backed enrollment uses the browser:

```console
curl --cacert /path/to/caddy-server-root.pem --cert user.pem --key user.key \
  https://localhost:5059/
curl --cacert /path/to/caddy-server-root.pem https://localhost:5059/
```

The first request should succeed for an issued, unexpired certificate. The
second must fail during TLS client authentication. Finally, verify that a
connection to `<host>:8000` cannot be made from another host.

## What you built

Caddy terminates the server TLS connection, validates a client certificate
against the central client CA, and proxies only authenticated requests to a
loopback-only HTTP application. Clients reach it by SSH forwarding to
`https://localhost:<port>`, not by DNS. Client clusters receive the signed
revocation list (normally a CRL) from a separate distribution relay or
deployment job, never from the signing server. Configure and test that path and
its verifier before declaring certificate revocation operational.
