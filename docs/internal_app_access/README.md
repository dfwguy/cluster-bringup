# Internal web-app access

This documentation describes passwordless access to internal HTTP applications
using Caddy and mutual TLS (mTLS). A central, SSO-protected
signing service issues a personal client certificate for each user. Caddy at
each site validates that certificate before proxying a request to the local
application.

Gunicorn is used throughout as a familiar example of a local HTTP upstream. It
is not a requirement: the same boundary works with any HTTP service that Caddy
can reverse-proxy, provided the upstream is reachable only through Caddy.

## Client connection model

Application sites do not need DNS names. A client first connects by SSH to the
site IP address, forwarding a local port to Caddy's loopback listener. The
browser then opens `https://localhost:<port>`; HTTPS and mTLS travel inside the
SSH tunnel. SSH access is a separate prerequisite and security boundary from
the client certificate.

## Network boundary

Client clusters and their Caddy hosts **must not have network access to the
signing server**. In particular, they must not pull a CRL from the signing
server over the VPN. The signing server publishes a signed revocation artifact
to a separate distribution relay or hands it to a controlled deployment job.
Clusters fetch only from that relay, or receive a push from it. The signing
server's CA private key, CA database, and issuance interface remain isolated.

This restriction applies to clusters, not necessarily to a user's workstation
when it uses the SSO-protected certificate portal.

The documentation follows [Diátaxis](https://diataxis.fr/): tutorials teach,
how-to guides solve a task, reference records facts, and explanations give the
reasoning behind the design.

| Type | Document | Use it when |
|---|---|---|
| Tutorial | [Deploy one protected application](tutorial.md) | You are setting up this access path for the first time |
| How-to | [Add a Caddy-protected site](how-to/add-caddy-site.md) | You need to deploy another app/site |
| How-to | [Revoke a client certificate](how-to/revoke-client-certificate.md) | A certificate must no longer grant access |
| How-to | [Enroll a client certificate](how-to/install-client-certificate.md) | You are enrolling a device with a client-generated CSR |
| Reference | [Configuration reference](reference/configuration.md) | You need paths, configuration, commands, or verification criteria |
| Explanation | [Architecture and trust boundaries](explanation/architecture-and-trust.md) | You need to understand how the trust and revocation model works |
| Explanation | [Rejected connection and enrollment methods](explanation/rejected-methods.md) | You need to understand why DNS/direct access and PFX issuance are excluded |

## Scope

This design is for internal applications where each site hosts an HTTP upstream
only on loopback (or another private Caddy-to-upstream network) and Caddy is
the sole network entry point. It does not replace
authorization inside an application: an authenticated certificate identity
must still be mapped to the application's permitted actions.

Client private keys are generated on the client device. The signing service
accepts a CSR and returns only the signed public certificate chain; it does not
generate client keys or distribute PFX files.

Before production use, select and test the revocation enforcement mechanism.
Use a centrally published, signed revocation list keyed by certificate serial
as the default: a CRL is the standard format for that list. It lets a site deny
one certificate without replacing certificates held by other users. The
standard Caddy build can require a client certificate issued by a trusted CA,
but its documented stock verifier is the allow-listed leaf verifier; consuming
a CRL or equivalent local deny-list requires a compatible custom verifier or a
separately designed enforcement mechanism.
