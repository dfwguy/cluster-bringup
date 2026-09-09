# How to verify GitLab API and repository access

Use these checks after creating or rotating the `nvis-ova` group token. Run
them from the credential workspace so Varlock can find `.env.schema` and
`.env.local`. Replace `<project-path>` with a path relative to the group, such
as `cluster-bringup` or `some-subgroup/some-project`.

## Validate the Varlock environment

```console
cd ~/git/nvis-ova
project_path="<project-path>"
project_dir="$HOME/git/nvis-ova/$project_path"
repository_url="https://gitlab-master.nvidia.com/nvis-ova/${project_path}.git"
npm exec -- varlock load --agent
```

The command must succeed and redact `GITLAB_TOKEN`. Do not inspect the resolved
environment with `echo`, `env`, `printenv`, shell tracing, or an unredacted
Varlock output format.

## Verify API authentication and token metadata

The following prints only the `/user` HTTP status and allow-listed metadata:

```console
npm exec -- varlock run --inject vars -- bash -c '
set -eu
user_file=$(mktemp)
token_file=$(mktemp)
trap '\''rm -f "$user_file" "$token_file"'\'' EXIT
header_config() {
  printf "header = \"PRIVATE-TOKEN: %s\"\n" "$GITLAB_TOKEN"
}
user_status=$(curl --silent --output "$user_file" --write-out "%{http_code}" \
  --config <(header_config) \
  "https://${GITLAB_HOST}/api/v4/user")
printf "/user HTTP %s\n" "$user_status"
test "$user_status" = 200
self_status=$(curl --silent --output "$token_file" --write-out "%{http_code}" \
  --config <(header_config) \
  "https://${GITLAB_HOST}/api/v4/personal_access_tokens/self")
printf "/personal_access_tokens/self HTTP %s\n" "$self_status"
test "$self_status" = 200
jq '{active, revoked, expires_at, scopes}' "$token_file"
jq -e '\''
  .active == true and .revoked == false and
  (["api", "read_api", "read_repository", "write_repository"]
    - (.scopes // []) | length == 0)
'\'' "$token_file" >/dev/null
user_id=$(jq -r .id "$user_file")
access_level=$(curl --silent --config <(header_config) \
  "https://${GITLAB_HOST}/api/v4/groups/401322/members/all/${user_id}" |
  jq -r .access_level)
printf "nvis-ova access level: %s\n" "$access_level"
test "$access_level" -eq 30
'
```

Expected results are HTTP `200`, `active: true`, `revoked: false`, an acceptable
future expiry, the four expected scopes, and access level `30` (Developer). If the
self-inspection endpoint is unavailable, verify token metadata in the approved
GitLab UI or with the Group Owner; do not skip the check silently.

## Verify repository read access

```console
GIT_ASKPASS="$PWD/gitlab-askpass.sh" \
GIT_TERMINAL_PROMPT=0 \
npm exec -- varlock run --inject vars -- \
git ls-remote \
  "$repository_url" HEAD
```

Success prints the remote `HEAD` commit without prompting.

## Verify feature-branch write access

This check requires an existing clone. It does not create the remote branch:

```console
GIT_ASKPASS="$PWD/gitlab-askpass.sh" \
GIT_TERMINAL_PROMPT=0 \
npm exec -- varlock run --inject vars -- \
git -C "$project_dir" \
  push --dry-run "$repository_url" \
  HEAD:refs/heads/<username>-token-access-check
```

Using the explicit HTTPS URL ensures this tests the group token even when an
existing clone has an SSH origin. Success proves authentication for a
feature-branch push. It does not test or grant permission to bypass a protected
default branch.
