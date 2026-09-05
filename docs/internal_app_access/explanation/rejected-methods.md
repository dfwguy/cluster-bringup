# Explanation: rejected connection and enrollment methods

This design makes two deliberate choices: application access uses an SSH
forward to a site IP rather than application DNS, and client enrollment uses a
client-generated CSR rather than a signing-server-generated PFX. These are
security and operating-boundary decisions, not missing features.

## Rejected: DNS-based or direct application connections

The application site does not receive a DNS name and Caddy does not expose an
application listener on the site network. A user first establishes SSH to the
site IP, then forwards a local port to Caddy's loopback listener:

```console
ssh -N -L 5059:127.0.0.1:5059 <ssh-user>@<site-ip>
```

The browser uses `https://localhost:5059/`. TLS and mTLS remain end-to-end
inside that SSH tunnel, but Caddy is reachable only through the authenticated
SSH session.

Using an application DNS name would create a separate directly reachable
application path, require a site-facing server certificate and DNS lifecycle,
and weaken the intended network boundary. It would also make it easier to
misconfigure Caddy or its upstream as network-reachable. The selected model
keeps Caddy and the HTTP upstream on loopback and makes SSH authorization an
explicit prerequisite to application access.

This is independent of the signing-server boundary: client clusters also never
reach the signing service. They receive public CA and revocation artifacts only
from the separate distribution relay or controlled deployment job.

## Rejected: signing-server-generated keys and PFX downloads

The signing service must not generate a client private key or return a PFX.
Although PFX delivery is convenient for browser import, it creates a portable
copy of the private key and makes the signing service temporarily handle that
key. A private key can then leak through temporary files, process memory,
crash dumps, backups, logs, a compromised portal, or a copied download.

The selected flow is client-generated CSR enrollment:

1. The client creates the key locally, preferably in a hardware-backed,
   non-exportable key store.
2. The client sends only the CSR, which contains the public key, through the
   SSO-protected enrollment service.
3. The signing service validates the SSO user and policy, signs the CSR, and
   returns only the public certificate chain.
4. The client enrollment mechanism installs that certificate against the
   original local key.

This gives the signing service no copy of the user private key. It does require
an enrollment mechanism for every supported platform and device: the mechanism
must create the key, submit the CSR, and bind the returned certificate to that
key. A lost device is re-enrolled with a new key and its old certificate is
revoked; recovering or copying its private key is not part of the design.
