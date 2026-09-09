# Omnistation GitLab group credentials

This guide shows how to keep an NVIS GitLab group access token in a Varlock
workspace on an Omnistation and use it with Git and Codex across repositories
in the `nvis-ova` GitLab group. Access to any particular project still depends
on the token's scopes, group role, and that project's policies.

Here, **group** always means a GitLab group, not a Linux or Unix user group. The
group credential workspace is a user-created directory that holds the shared
Varlock configuration and launch helpers. Each cloned project remains its own
Git repository.

The documentation follows [Diátaxis](https://diataxis.fr/): the tutorial teaches
one complete path, how-to guides solve specific tasks, reference records facts,
and explanation describes the security and repository boundaries.

| Type | Document | Use it when |
|---|---|---|
| Tutorial | [Set up Varlock group credentials](tutorial.md) | You are creating the workspace and connecting a new or existing group-project clone |
| How-to | [Rotate a group token](how-to/rotate-group-token.md) | The token is expiring, revoked, or being replaced |
| How-to | [Verify GitLab access](how-to/verify-gitlab-access.md) | You need to confirm scopes, group role, repository reads, and feature-branch writes |
| How-to | [Troubleshoot GitLab access](how-to/troubleshoot-gitlab-access.md) | API or Git authentication is failing |
| How-to | [Launch Codex for an existing repository](how-to/launch-codex-for-existing-repository.md) | The reusable launcher should start or resume Codex in any permitted group repository |
| Reference | [Varlock and GitLab credential reference](reference/varlock-gitlab-reference.md) | You need variables, decorators, paths, permissions, commands, or status meanings |
| Explanation | [Credential workspace and runtime trust](explanation/credential-workspace-and-runtime-trust.md) | You need to understand why the credential workspace is separate and what Varlock does and does not protect |

## Scope

This is the NVIS convention for sharing one group credential configuration
across one or more project repositories. The workspace can be a plain directory
or be managed separately, provided `.env.local`, `node_modules/`, and other
machine-local material are never committed. Varlock itself does not require
this layout; an application can instead keep `.env.schema` in its repository.

The stable workflow documented here uses device-local encryption at rest and
raw environment injection at runtime. Varlock's credential proxy is an
early-preview alternative, not the default; its limitations are described in
the [security explanation](explanation/credential-workspace-and-runtime-trust.md).
