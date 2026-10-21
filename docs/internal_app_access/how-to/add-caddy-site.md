# How to add a Caddy-protected site

Use this guide to deploy an additional HTTP application under the existing
client-certificate CA. Gunicorn is an example; any HTTP upstream works.

1. Install the public client CA as `/etc/caddy/ca.pem` from the approved
   deployment artifact. Verify its fingerprint through the approved out-of-band
   process; do not give the Caddy host network access to the signing server.
2. Bind the new HTTP service to a unique loopback address, for example
   `127.0.0.1:8010`; do not publish that port.
3. Add a Caddy site block using a loopback listener. Clients will reach it with
   an SSH forward to the site's IP address, then browse to `localhost`; no site
   DNS name is needed:

   ```text
   localhost:5060 {
       tls internal {
           client_auth {
               mode require_and_verify
               trust_pool file {
                   pem_file /etc/caddy/ca.pem
               }
           }
       }

       reverse_proxy 127.0.0.1:8010 {
           header_up X-Client-CN {tls_client_subject}
       }
   }
   ```

4. Add the site's signed revocation-list synchronization unit or timer and
   perform the initial sync from the approved distribution relay—not the
   signing server. A CRL is the preferred artifact because the CA signs it and
   it contains only revoked serials. Do not describe revocation as enforced
   until the selected Caddy verifier has been proven to reject an intentionally
   revoked test certificate.
5. Validate and reload Caddy:

   ```console
   sudo caddy validate --config /etc/caddy/Caddyfile --adapter caddyfile
   sudo systemctl reload caddy
   ```

6. From a client, run `ssh -N -L 5060:127.0.0.1:5060 <ssh-user>@<site-ip>` and
   test `https://localhost:5060/` with an issued certificate and without one.
   Confirm that the application sees the expected identity and cannot be
   contacted through the upstream service directly.

If clients do not already trust the server certificate issuer, distribute the
appropriate server root certificate for `localhost`. Do not distribute the
client CA private key; it is unrelated to the server TLS trust chain.
