# Explanation: why identities are separate

The cluster needs three different kinds of identity because they answer three
different questions: who is using the cluster, who owns the Rack Status
process, and what account runs unattended work.

## Individual accounts make human actions attributable

Giving every person their own BCM-managed identity means SSH, scheduler, and
sudo records can identify the person who performed an action. A shared account
cannot provide that evidence, and changing a shared password or key disrupts
everyone who uses it.

BCM is the identity source so an account is handled consistently across the
managed fleet. Local account creation on one node creates drift: access may
work on that one host but fail elsewhere, and removal becomes unreliable.

## Public keys remove the password path, not the need for control

A passwordless account is not an unprotected account. The private key is the
authentication secret and stays with its owner; BCM or the managed key system
stores only the corresponding public key. Disabling password authentication
avoids password sharing, guessing, and rotation, while key fingerprints,
revocation, and access reviews still provide control.

## Service accounts separate ownership from operation

`cmods` owns the NVIS Rack Status process, so its files, configuration, and
logs retain stable service ownership even as individual operators change.
`cmods-automation` runs unattended automation on the app-server/slogin server,
separating scheduled work from both humans and the process-owner account.

An operator who needs to act as either service account starts by logging in as
themself and then uses authorized `sudo`. This preserves both pieces of the
story: the service identity that performed the operation and the individual
who initiated it. Direct shared logins would erase that boundary.

## Why host placement matters

The app-server/slogin server is the approved place for automation and login
entry. Keeping automation there gives it a predictable runtime environment,
centralizes its logs and scheduling, and avoids placing long-lived operational
credentials or background work on compute nodes. BCM makes the required human
identities available; the automation account remains constrained to its
specific operational role and host.
