# Omnistation GitLab group credentials

This guide shows how to keep an NVIS GitLab group access token in a Varlock
workspace on an Omnistation and use it with Git and Codex. The worked example
uses the `nvis-ova` GitLab group and its existing `cluster-bringup` project.

Here, **group** always means a GitLab group, not a Linux or Unix user group. The
group credential workspace is a user-created parent directory. It is not a Git
repository and it does not replace the repositories cloned beneath it.

The documentation follows [Diátaxis](https://diataxis.fr/): the tutorial teaches
one complete path, how-to guides solve specific tasks, reference records facts,
and explanation describes the security and repository boundaries.

| Type | Document | Use it when |
|---|---|---|
| Tutorial | [Set up Varlock group credentials](tutorial.md) | You are creating the workspace and cloning `cluster-bringup` for the first time |
| How-to | [Rotate a group token](how-to/rotate-group-token.md) | The token is expiring, revoked, or being replaced |
| How-to | [Verify GitLab access](how-to/verify-gitlab-access.md) | You need to confirm scopes, group role, repository reads, and feature-branch writes |
| How-to | [Troubleshoot GitLab access](how-to/troubleshoot-gitlab-access.md) | API or Git authentication is failing |
| How-to | [Launch Codex for an existing repository](how-to/launch-codex-for-existing-repository.md) | The child repository already exists and Codex should start there |
| Reference | [Varlock and GitLab credential reference](reference/varlock-gitlab-reference.md) | You need variables, decorators, paths, permissions, commands, or status meanings |
| Explanation | [Credential workspace and runtime trust](explanation/credential-workspace-and-runtime-trust.md) | You need to understand why the parent workspace is separate and what Varlock does and does not protect |

## Scope

This is the NVIS convention for group credentials before one or more group
projects have been cloned. Varlock itself does not require this parent-child
layout. An ordinary application can keep `.env.schema` in its own repository.

The stable workflow documented here uses device-local encryption at rest and
raw environment injection at runtime. Varlock's credential proxy is an
early-preview alternative, not the default; its limitations are described in
the [security explanation](explanation/credential-workspace-and-runtime-trust.md).
