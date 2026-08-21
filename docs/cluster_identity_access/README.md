# Cluster identity and automation access

This guide describes the basic access model for the cluster:

- Each person receives an individual cluster account.
- NVIDIA Base Command Manager (BCM) is the system of record that provisions
  those accounts and makes them available on BCM-managed hosts.
- Ordinary cluster-tenant accounts are created with one selected primary group:
  `cmods`, `nvis-eth`, or `nvis-ib`.
- Authentication is by SSH public key. No account has an SSH password.
- `cmods` runs NVIS Rack Status and automatically executed tests on the
  app-server or slogin server through systemd services and Docker containers.
- An authorized operator can use `sudo` to act as `cmods` when an operational
  task requires it.

The documentation follows [Diátaxis](https://diataxis.fr/): tutorials teach,
how-to guides solve a task, reference records facts, and explanations give the
reasoning behind the design.

| Type | Document | Use it when |
|---|---|---|
| Tutorial | [Provision a person for passwordless cluster access](tutorial.md) | You are onboarding a person for the first time |
| How-to | [Operate a service as `cmods`](how-to/operate-as-service-account.md) | You need to inspect, run, or recover Rack Status or an automated test |
| Reference | [Access-model reference](reference/access-model.md) | You need the role, host, authentication, or verification rules |
| Explanation | [Why identities are separate](explanation/identity-boundaries.md) | You need to understand the security and audit boundaries |

## Scope

This guide describes the installed provisioning workflow at
`/home/nvis/utils/add_user.sh`, stored in this repository as
[`scripts/aic_bcm_headnode_add_user.sh`](../../scripts/aic_bcm_headnode_add_user.sh).
It creates ordinary cluster-tenant users through BCM, then installs and verifies
one SSH public key in the user's home directory. The script's `nvis` names are
shared NVIS/AIC platform names and are intentionally retained.
