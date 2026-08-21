# Cluster identity and automation access

This guide describes the basic access model for the cluster:

- Each person receives an individual cluster account.
- NVIDIA Base Command Manager (BCM) is the system of record that provisions
  those accounts and makes them available on BCM-managed hosts.
- Authentication is by SSH public key. No account has an SSH password.
- Scheduled or non-human work runs as `cmods-automation` on the app-server or
  slogin server.
- `cmods` owns and operates the NVIS Rack Status process. An authorized
  operator can use `sudo` to act as `cmods` or `cmods-automation` when an
  operational task requires that identity.

The documentation follows [Diátaxis](https://diataxis.fr/): tutorials teach,
how-to guides solve a task, reference records facts, and explanations give the
reasoning behind the design.

| Type | Document | Use it when |
|---|---|---|
| Tutorial | [Provision a person for passwordless cluster access](tutorial.md) | You are onboarding a person for the first time |
| How-to | [Operate a service as `cmods` or `cmods-automation`](how-to/operate-as-service-account.md) | You need to inspect, run, or recover the Rack Status process |
| Reference | [Access-model reference](reference/access-model.md) | You need the role, host, authentication, or verification rules |
| Explanation | [Why identities are separate](explanation/identity-boundaries.md) | You need to understand the security and audit boundaries |

## Scope

This is a process guide, not a replacement for the site's BCM administrator
runbook. BCM versions and local policy determine the exact `cmsh` commands,
account-group assignments, and public-key registration method. Record those
site-specific details in the change/request that provisions the account.
