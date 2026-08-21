# Cluster identity and automation access

This guide describes the basic access model for the cluster:

- Each person receives an individual cluster account.
- NVIDIA Base Command Manager (BCM) is the system of record that provisions
  those accounts and makes them available on BCM-managed hosts.
- Every individual account, `cmods`, and `cmods-automation` is a member of the
  shared `cmods` group.
- Authentication is by SSH public key. No account has an SSH password.
- `cmods` runs NVIS Rack Status on the app-server or slogin server.
- `cmods-automation` runs automatically executed tests on the app-server or
  slogin server.
- Both service identities run their work through systemd services and Docker
  containers. An authorized operator can use `sudo` to act as either identity
  when an operational task requires it.

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
