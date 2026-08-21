# Reference: cluster access model

## Identities

| Identity | Kind | Primary purpose | Normal login method |
|---|---|---|---|
| Individual user | Human | Interactive cluster use and attributable actions | SSH public key to an approved login endpoint |
| `cmods` | Service/operations | Runs NVIS Rack Status and automatically executed tests | Not a shared human login; runs through systemd and Docker |

## Ordinary-user primary groups

[`aic_bcm_headnode_add_user.sh`](../../../scripts/aic_bcm_headnode_add_user.sh)
is the repository copy of the deployed `/home/nvis/utils/add_user.sh`. It
requires one primary group for each ordinary cluster-tenant user. The permitted choices
are `cmods`, `nvis-eth`, and `nvis-ib`. The selected group's BCM GID must match
the GID reported by NSS before the script creates the account. Membership or
primary-group assignment does **not** by itself grant permission to use `sudo`.

## Authoritative systems and locations

| Item | Authority/location | Rule |
|---|---|---|
| User account lifecycle | BCM | Create, change, and remove managed identities through BCM's approved process |
| Ordinary-user primary group | BCM | One of `cmods`, `nvis-eth`, or `nvis-ib`, selected by the provisioning operator |
| Account provisioning | [`scripts/aic_bcm_headnode_add_user.sh`](../../../scripts/aic_bcm_headnode_add_user.sh) | Repository copy of `/home/nvis/utils/add_user.sh`; creates BCM account, validates NSS identity, creates home, and installs one public key |
| Login availability | BCM-managed app-server/slogin server | Verify new accounts here before handoff |
| Human authentication | SSH public keys | Each person controls their own private key |
| SSH password authentication | BCM user setting | The provisioning script sets `disablepasswordssh yes` |
| Service execution | `cmods` on app-server/slogin | Runs NVIS Rack Status and automatically executed tests through configured systemd and Docker workloads |
| `cmods` sudo on BCM headnode and app-server/slogin | Not granted | `cmods` must not be able to use `sudo` on these hosts |
| `cmods` sudo on BCM-managed hosts | Granted | `cmods` must be able to use `sudo` on managed hosts |
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
| Service operation | `id` shows `cmods`; action is recorded against the operator's sudo event |
| Automated-test deployment | The test runs as `cmods` through its configured systemd service and Docker container on the approved app-server/slogin host |
| `cmods` sudo boundary | `sudo -l -U cmods` denies sudo on the BCM headnode and app-server/slogin, and permits it on a managed host |
