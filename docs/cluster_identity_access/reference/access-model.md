# Reference: cluster access model

## Identities

| Identity | Kind | Primary purpose | Normal login method |
|---|---|---|---|
| Individual user | Human | Interactive cluster use and attributable actions | SSH public key to an approved login endpoint |
| `cmods` | Service/operations | Runs NVIS Rack Status | Not a shared human login; runs through systemd and Docker; assumed with authorized `sudo` when needed |
| `cmods-automation` | Service/automation | Runs automatically executed tests | Runs through systemd and Docker on the app-server/slogin server; assumed with authorized `sudo` for operations |

## Shared group

`cmods` is both the name of a service account and the name of the shared group.
Every individual cluster account, the `cmods` service account, and the
`cmods-automation` service account belongs to the `cmods` group. This group
membership supports shared cluster access and file permissions; it does **not**
by itself grant permission to use `sudo` as either service account.

## Authoritative systems and locations

| Item | Authority/location | Rule |
|---|---|---|
| User account lifecycle | BCM | Create, change, and remove managed identities through BCM's approved process |
| Shared group membership | BCM `cmods` group | Every person and both service accounts must be members |
| Login availability | BCM-managed app-server/slogin server | Verify new accounts here before handoff |
| Human authentication | SSH public keys | Each person controls their own private key |
| Passwords | None | Do not set, distribute, or rely on SSH passwords |
| Rack Status execution | `cmods` | Runs NVIS Rack Status through its configured systemd and Docker workload |
| Automated-test execution | `cmods-automation` on app-server/slogin | Runs automatically executed tests through their configured systemd and Docker workloads |
| Privilege transition | `sudo -u <target>` | Starts with an individual account and must be explicitly authorized |

## Required controls

- Grant the smallest BCM group and scheduler/project entitlement that meets the
  approved purpose.
- Verify a supplied public-key fingerprint out of band before registration.
- Disable or leave unusable password authentication for every relevant account.
- Use an individual account to reach a service identity; never distribute a
  shared service key or password to operators.
- Restrict `sudo` policy to approved operators, target identities, and commands
  where practical. Review it with account-access reviews.
- Record provisioning, key changes, service-account use, and deprovisioning in
  the normal change or ticket system.

## Minimum acceptance checks

| Change | Evidence of success |
|---|---|
| New human account | Key-only SSH succeeds as that account; a password-only attempt fails |
| Key rotation | New key succeeds, old key fails after the approved overlap period |
| Access removal | User lookup and/or login is denied on the target login endpoint |
| Service operation | `id` shows `cmods` or `cmods-automation`; action is recorded against the operator's sudo event |
| Automated-test deployment | The test runs as `cmods-automation` through its configured systemd service and Docker container on the approved app-server/slogin host |
