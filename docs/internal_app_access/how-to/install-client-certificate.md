# How to enroll a client certificate

This design requires a client-generated CSR. Do not download a PFX and do not
send a private key to the signing portal. Use the approved enrollment mechanism
for the platform; it must create the private key locally, submit the CSR through
the SSO-protected service, and install the returned certificate chain against
that key.

## Required behavior for every platform

1. Generate a new device-local private key, preferably in a hardware-backed,
   non-exportable key store.
2. Generate a CSR from that key and submit it while signed in to the approved
   SSO enrollment service.
3. Receive only the issued public certificate and CA chain.
4. Bind the issued certificate to the original local key using the same
   enrollment mechanism.
5. Create the SSH forward and open `https://localhost:<port>` to confirm that
   the browser offers the certificate.

Windows, macOS, and Linux require platform-specific enrollment support—for
example, a managed-device profile, an MDM enrollment protocol, a smart-card
tool, or an approved local enrollment client. Generic certificate-file import
is not sufficient unless that tool can prove it binds the returned certificate
to the original private key. The enrollment mechanism must never export or
upload the private key.

Trusting Caddy's server root is separate from client enrollment. The server
root prevents a browser warning for `https://localhost:<port>`; the client
certificate authenticates the user to Caddy.
