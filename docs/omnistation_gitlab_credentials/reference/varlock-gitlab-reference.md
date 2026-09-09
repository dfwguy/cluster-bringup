# Reference: Varlock-backed NVIS GitLab credentials

This page records the fixed values, interfaces, and meanings used by the
`nvis-ova` Omnistation workflow. Follow the [tutorial](../tutorial.md) for the
ordered first-time setup.

## Paths and ownership

| Path | Owner and purpose |
|---|---|
| `~/git/nvis-ova` | User-created Varlock group credential workspace; may hold or sit alongside multiple project clones |
| `~/git/nvis-ova/.env.schema` | Shareable schema and non-secret defaults |
| `~/git/nvis-ova/.env.local` | Device-local encrypted token payload; never share or commit; mode `600` |
| `~/git/nvis-ova/gitlab-askpass.sh` | Git prompt adapter containing literal variable references; mode `700` |
| `~/git/nvis-ova/codex-varlock-yolo.sh` | Owner-only reusable Varlock/Codex launcher; contains no credential value; mode `700` |
| `~/git/nvis-ova/package.json` | Exact Varlock dependency declaration |
| `~/git/nvis-ova/package-lock.json` | Reproducible npm dependency lock |
| `~/git/nvis-ova/node_modules/` | Local npm installation; ignored |
| `~/git/nvis-ova/<project-path>/.git/` | A cloned project's independent Git history |

Each project clone has its own work tree and history. Machine-local credential
files must be ignored anywhere the credential workspace itself is tracked.

## Environment variables

| Variable | Classification | Required value or meaning |
|---|---|---|
| `GITLAB_HOST` | Public, required | `gitlab-master.nvidia.com` |
| `GITLAB_USERNAME` | Public, required | Any non-empty HTTPS username; this workflow uses `oauth2` |
| `GITLAB_TOKEN` | Sensitive, required | GitLab group access token used as the HTTPS password and API token; minimum length validated as 20 characters |
| `GIT_ASKPASS` | Runtime control | Absolute path to executable `gitlab-askpass.sh` in the credential workspace |
| `GIT_TERMINAL_PROMPT` | Runtime control | `0` to prevent interactive fallback |

Git does not interpret `GITLAB_TOKEN` on its own. When Git requests a username
or password, it invokes `GIT_ASKPASS` with the prompt text and reads one answer
from the program's standard output.

## Varlock schema decorators

| Decorator | Effect in this schema |
|---|---|
| `@defaultSensitive=false` | Items are not sensitive unless marked otherwise |
| `@defaultRequired=false` | Items are not required unless marked otherwise |
| `@public` | Declares the hostname or username safe for normal display |
| `@sensitive` | Redacts the token in agent-safe output and enables sensitive-value handling |
| `@required` | Fails validation when the value is absent |
| `@type=domain` | Validates the GitLab hostname as a domain |
| `@type=string(minLength=1)` | Requires a non-empty Git username |
| `@type=string(minLength=20)` | Rejects an implausibly short token without assuming a token prefix |

Root decorators belong in the header above the single `# ---` separator and
must not be duplicated when replacing a generated schema.

## Expected GitLab token configuration

| Scope | Capability retained in the NVIS configuration |
|---|---|
| `api` | Read and write GitLab API access within the token's group scope |
| `read_api` | Read GitLab API access within the token's group scope |
| `read_repository` | Git-over-HTTP reads for repositories in the group |
| `write_repository` | Git-over-HTTP reads and writes for repositories in the group; it does not authenticate API requests |

All four scopes are expected even where one technically overlaps another. The
token role and token scopes are separate controls: both must permit an action.

Relevant access-level values are:

| Value | GitLab role | Use here |
|---:|---|---|
| `10` | Guest | Insufficient |
| `20` | Reporter | Insufficient for feature-branch pushes |
| `30` | Developer | Selected role for this workflow |
| `40` | Maintainer | Broader than this workflow requires |
| `50` | Owner | Broader than this workflow requires; normally required to create a group access token |

Protected-branch rules still apply. Developer access supports ordinary
feature-branch pushes and merge-request creation but does not bypass them.

## Token state and expiration

`GET /api/v4/personal_access_tokens/self` returns the authenticating token's
metadata when supported by the installed GitLab version. Required state is
`active: true`, `revoked: false`, an expiry acceptable under NVIDIA policy, and
all four scopes above.

GitLab access tokens expire at midnight UTC on their expiry date. After
expiration they cannot authenticate. Revocation invalidates a token
immediately and cannot be undone.

## HTTP results

| Result | Meaning |
|---|---|
| `200` from `/api/v4/user` | Token authentication succeeded |
| `401` | Token is missing, invalid, expired, revoked, or incorrectly loaded |
| `403` | Caller authenticated but lacks authorization for the operation |
| `404` from token self-inspection | Endpoint may be unavailable on that GitLab version; confirm metadata through the approved UI or owner |
| Connection or TLS error | Network, VPN, DNS, hostname, proxy, or trust failure rather than an HTTP authorization result |

## Varlock command behavior

| Command or option | Behavior |
|---|---|
| `varlock load --agent` | Resolves and validates configuration, emits agent-oriented JSON, and redacts sensitive values |
| `varlock run -- command` | Resolves configuration and runs a child with injected environment data |
| `varlock run --inject vars -- command` | Injects individual variables but omits the additional `__VARLOCK_ENV` serialized blob |
| `varlock run --path PATH -- command` | Uses the named file or directory as the Varlock entry point |
| `varlock scan --staged` | Scans staged Git files for resolved sensitive values known to the selected Varlock schema |

`varlock run` makes each injected individual variable available to the child
process. `--inject vars` reduces unnecessary exposure by omitting the blob; it
does not hide `GITLAB_TOKEN` from the child.

## Reusable launcher behavior

| Invocation | Behavior |
|---|---|
| `codex-varlock-yolo.sh` | Runs `codex … resume --last` from the credential workspace |
| `codex-varlock-yolo.sh ARGS...` | Forwards `ARGS...` to Codex instead of the default resume arguments |
| `codex-varlock-yolo.sh -C PROJECT_DIR` | Starts a new session rooted at any selected project clone |
| `codex-varlock-yolo.sh -C PROJECT_DIR resume --last` | Resumes the most recent session associated with that clone |

The launcher always configures askpass, disables terminal credential prompts,
uses the credential workspace as Varlock's `--path`, selects `--inject vars`,
and enables `--dangerously-bypass-approvals-and-sandbox`. Its mode is `700`,
and it stores no resolved credential.

## Command synopsis

```console
npm exec -- varlock load --agent
npm exec -- varlock run --inject vars -- <command> [args...]
npm exec -- varlock run --path ~/git/nvis-ova --inject vars -- <command>
~/git/nvis-ova/codex-varlock-yolo.sh
~/git/nvis-ova/codex-varlock-yolo.sh \
  -C "$HOME/git/nvis-ova/<project-path>" resume --last
git ls-remote <repository-url> HEAD
git -C "$HOME/git/nvis-ova/<project-path>" push --dry-run <repository-url> \
  HEAD:refs/heads/<feature-branch>
```

Use the selected clone as the working directory, or supply it with `git -C`.

## Validated versions and primary documentation

Validated on 2026-09-09: Varlock `1.18.0`, Node.js `22.23.2`, npm `10.9.8`,
Codex CLI `0.153.4`, Git `2.43.0`, curl `8.5.0`, and jq `1.7`.

- [Varlock installation](https://varlock.dev/getting-started/installation/)
- [Varlock schema](https://varlock.dev/guides/schema/)
- [Varlock local encryption](https://varlock.dev/guides/local-encryption/)
- [Varlock AI tools](https://varlock.dev/guides/ai-tools/)
- [Varlock load and run](https://varlock.dev/reference/cli/load-and-run/)
- [Varlock credential proxy](https://varlock.dev/guides/proxy/)
- [GitLab group access tokens](https://docs.gitlab.com/user/group/settings/group_access_tokens/)
- [GitLab token scopes](https://docs.gitlab.com/security/tokens/access_token_scopes/)
- [GitLab token self-inspection](https://docs.gitlab.com/api/personal_access_tokens/)
- [Git credentials](https://git-scm.com/docs/gitcredentials)
- [Codex CLI reference](https://developers.openai.com/codex/cli/reference)
- [Diátaxis](https://diataxis.fr/)
