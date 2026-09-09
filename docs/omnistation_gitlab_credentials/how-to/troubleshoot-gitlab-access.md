# How to troubleshoot Varlock-backed GitLab access

Work from the top of this page. Keep terminal prompting disabled so a failed
non-interactive credential path does not hang or fall back to manual entry.

## Classify the failure

| Symptom | Likely cause | Action |
|---|---|---|
| `/api/v4/user` returns `401` | Token is missing, invalid, expired, revoked, or not resolved | Run `npm exec -- varlock load --agent`; rotate the token if its metadata is inactive |
| An authenticated API request returns `403` | The token identity lacks the required role or the operation is forbidden | Confirm group access level `30` and applicable project policy |
| curl reports name resolution, connection, or TLS failure | VPN, route, hostname, proxy, or system trust is wrong | Restore the approved network path and CA trust; never use `--insecure` |
| Git prompts or hangs | `GIT_ASKPASS` is missing/non-executable, or `GIT_TERMINAL_PROMPT` is not `0` | Check the path and mode, then rerun through Varlock |
| Git rejects otherwise valid credentials | Another credential helper supplied stale credentials | Bypass helpers for the diagnostic command as shown below |
| `not a git repository` | Git did not target a project clone | Change directory or use `git -C ~/git/nvis-ova/<project-path>` |

## Confirm Varlock resolution safely

```console
cd ~/git/nvis-ova
npm exec -- varlock load --agent
```

Fix schema errors before testing GitLab. Sensitive values must remain redacted;
do not use `echo`, `env`, `printenv`, shell tracing, or raw output formats.

## Separate API authentication from authorization

Use the HTTP-status-only command in tutorial step 11, then the metadata and
role check in [verify GitLab access](verify-gitlab-access.md). A public endpoint
returning content does not prove the token authenticated. `/api/v4/user`
returning `200` does.

`401` concerns authentication. `403` means the request reached GitLab but was
not permitted. Developer access is numeric level `30`; Guest level `10` is not
sufficient for this workflow even when the token has every scope.

## Check the askpass path and permissions

```console
cd ~/git/nvis-ova
test -f "$PWD/gitlab-askpass.sh"
test -x "$PWD/gitlab-askpass.sh"
test "$(stat -c %a "$PWD/gitlab-askpass.sh")" = 700
```

The script belongs in the credential workspace and must contain variable
references rather than resolved values. Git does not automatically read
`GITLAB_TOKEN`.

## Bypass an interfering credential helper for one check

This diagnostic changes no Git configuration:

```console
project_path="<project-path>"
project_dir="$HOME/git/nvis-ova/$project_path"
GIT_ASKPASS="$PWD/gitlab-askpass.sh" \
GIT_TERMINAL_PROMPT=0 \
npm exec -- varlock run --inject vars -- \
git -c credential.helper= ls-remote \
  "https://gitlab-master.nvidia.com/nvis-ova/${project_path}.git" HEAD
```

If this works while the ordinary command fails, inspect configured helpers
for the selected repository:

```console
git -C "$project_dir" config --show-origin \
  --get-all credential.helper
```

Do not delete or overwrite a shared credential configuration until its other
users are understood.

## Distinguish location errors from authentication errors

Point repository commands at the intended clone:

```console
git -C "$project_dir" status --short --branch
```

A `not a git repository` error says nothing about the token. An HTTP `401`,
`403`, or explicit Git authentication failure is credential-related.
