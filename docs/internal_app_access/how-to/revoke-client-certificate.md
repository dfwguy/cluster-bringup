# How to revoke a client certificate

Revoke every active certificate for a user when they are offboarded, lose a
device, or report suspected key compromise. Use the issuance registry to find
all serials; do not assume one user has only one certificate.

1. Locate the issued certificate and the matching CA database record by serial.
2. Revoke the certificate on the signing server:

   ```console
   sudo -u signing openssl ca -config /secure/openssl.cnf \
     -revoke /secure/issued-certs/alice-<serial>.pem
   ```

3. Generate a fresh CRL. This is the signed serial deny-list that sites
   consume; it blocks the selected certificate without changing any unaffected
   user's certificate:

   ```console
   sudo -u signing openssl ca -config /secure/openssl.cnf \
     -gencrl -out /secure/public/crl.pem
   ```

4. Publish the CRL to the separate distribution relay, or give it to the
   controlled deployment job. Do not expose the signing server to client
   clusters and do not make cluster hosts pull from it.
5. Mark the registry entry `revoked`, including the time, actor, and reason.
6. Trigger a sync from the distribution relay to every Caddy host (or trigger
   the relay's push). Verify both the received CRL fingerprint and the Caddy
   reload or verifier refresh on each host.
7. Test with the revoked certificate against a staging site or controlled
   endpoint. It must be rejected. Record the completion time and compare it to
   the defined propagation objective.

For a 15-minute pull interval from the distribution relay, a revoked
certificate can remain usable for up to roughly one interval plus
transfer/reload time. Use a relay-driven push for an emergency revocation. A
CRL file alone does not cause standard Caddy to
reject a certificate: the configured verifier must consume it. A hand-written
Caddy allow-list is not an equivalent default: it requires distributing every
newly issued certificate to every site.
