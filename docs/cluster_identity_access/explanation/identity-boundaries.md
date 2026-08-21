# Explanation: why identities are separate

People use individual BCM-managed accounts. `cmods` runs NVIS Rack Status and
automatically executed tests through systemd services and Docker containers on
the app-server/slogin server. For each ordinary cluster-tenant user, the provisioning script selects the BCM
primary group needed for that user's role.

## Individual accounts make human actions attributable

Giving every person their own BCM-managed identity means SSH, scheduler, and
sudo records can identify the person who performed an action. A shared account
cannot provide that evidence, and changing a shared password or key disrupts
everyone who uses it.

BCM is the identity source so an account is handled consistently across the
managed fleet. Local account creation on one node creates drift: access may
work on that one host but fail elsewhere, and removal becomes unreliable.

For ordinary cluster-tenant accounts, the provisioning script selects exactly one primary
group from `cmods`, `nvis-eth`, and `nvis-ib`. The group choice supports the
user's role; it is not a substitute for `sudo`, and does not let a person
operate as `cmods`.

## Public keys remove the password path, not the need for control

A passwordless account is not an unprotected account. The private key is the
authentication secret and stays with its owner; BCM or the managed key system
stores only the corresponding public key. Disabling password authentication
avoids password sharing, guessing, and rotation, while key fingerprints,
revocation, and access reviews still provide control.

## Service accounts separate workloads from people

`cmods` runs NVIS Rack Status and automatically executed tests on the
app-server/slogin server. Both workloads are launched and managed through
systemd services and Docker containers, not interactive shared-account logins.
This keeps their files, configuration, logs, and runtime stable even as
individual operators change.

An operator who needs to act as `cmods` starts by logging in as themself and
then uses authorized `sudo`. This preserves both pieces of the story: the
service identity that performed the operation and the individual who initiated
it. Direct shared logins would erase that boundary.

`cmods` has no sudo privilege on the BCM headnode or the app-server/slogin
server. It does have sudo privilege on BCM-managed hosts, where it performs
managed-host operations.

## Why host placement matters

The app-server/slogin server is the approved place for these service workloads
and for login entry. Keeping systemd services and Docker containers there gives
them a predictable runtime environment, centralizes logs and scheduling, and
avoids placing long-lived operational credentials or background work on compute
nodes. BCM makes the required human identities available; each service account
remains constrained to its specific workload and host.
