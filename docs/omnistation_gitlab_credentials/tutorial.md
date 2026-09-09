# Tutorial: use a Varlock GitLab group token on an Omnistation

By the end of this tutorial, a device-local encrypted group access token can
authenticate to the NVIDIA GitLab API, read an existing repository in the
`nvis-ova` group, and dry-run a feature-branch push. Codex will run through
Varlock, and the launcher can be reused for other repositories that the group
token is authorized to access.

The commands were validated on 2026-09-09 with Varlock `1.18.0`, Node.js
`22.23.2`, npm `10.9.8`, Codex CLI `0.153.4`, Git `2.43.0`, and curl `8.5.0`.
The checks also use jq `1.7`. Varlock `1.18.0` was the current npm release on
that date.

**You will need**

- An Omnistation with Node.js 22.3 or newer, npm, Codex, Git, curl, and `jq`.
- The NVIDIA VPN or another approved network path to
  `gitlab-master.nvidia.com`.
- An existing project in the `nvis-ova` GitLab group to which the token should
  have access.
- A Group Owner who can create the token if you do not have that role.
- A dedicated, externally isolated environment if you will use the included
  Codex YOLO launcher.

## 1. Review the directory layout

The default layout is shown below. `<project-path>` may be a single project
name or include subgroup directories.

```text
~/git/nvis-ova/
├── .env.schema
├── .env.local
├── .gitignore
├── codex-varlock-yolo.sh
├── gitlab-askpass.sh
├── package.json
├── package-lock.json
├── node_modules/
└── <project-path>/
    └── .git/
```

`~/git/nvis-ova` is the Varlock credential workspace. Each cloned project has
its own `.git/` directory and history. Keep `.env.local` and other machine-local
credential material out of every repository. A project already cloned
elsewhere can remain there; the launcher accepts its absolute path.

This credential workspace is an NVIS convention that lets group credentials
exist before a repository is cloned and supports more than one repository in
the same GitLab group. It is not a universal Varlock layout. Ordinary Varlock
applications can place `.env.schema` directly in their application repository.

## 2. Check the Omnistation prerequisites

Confirm the required tools are installed:

```console
node --version
npm --version
codex --version
git --version
curl --version
jq --version
```

Connect to the NVIDIA VPN or approved network path, then verify DNS and TLS
reachability without disabling certificate checks:

```console
curl --head --silent --show-error \
  https://gitlab-master.nvidia.com/users/sign_in >/dev/null
```

## 3. Create the GitLab group access token

1. Open the `NVIS-OVA` group itself in GitLab.
2. Select **Group Settings > Access tokens**.
3. Confirm the breadcrumb names the group, not an individual project.
4. Enter the token name and expiration date required by group policy.
5. In **Select a role**, select **Developer**.
6. Select all four expected NVIS scopes: `api`, `read_api`, `read_repository`,
   and `write_repository`.
7. Create the token and copy it when GitLab displays it.
8. Store it securely immediately. GitLab does not display it again.

Creating a group access token normally requires the Group Owner role. If you
are not an Owner, obtain it through the group's approved owner or credential-
provisioning process. Use a group access token, rather than a project access
token, for this shared workflow.

## 4. Create the group workspace

Create the directory yourself and enter it:

```console
mkdir -p ~/git/nvis-ova
cd ~/git/nvis-ova
```

This directory is not created by another tool. If it is tracked as a separate
repository, apply the ignore rules in step 9 before staging anything.

## 5. Install and pin Varlock

Protect a pre-existing `package.json`; initialize npm only when it is absent:

```console
test -e package.json || npm init -y
npm install --save-exact varlock@1.18.0
npm exec -- varlock --version
```

The final command must print `1.18.0`. The exact dependency and generated
`package-lock.json` prevent a future install from silently selecting a new
Varlock release.

## 6. Initialize Varlock

Run Varlock's initialization command from the credential workspace:

```console
npm exec -- varlock init
```

The generated `.env.schema` is only a starting point and must be reviewed. The
next step backs it up before installing the NVIS schema. If `.env.schema` has
already been customized, stop and merge the required entries manually instead
of replacing it.

```console
test ! -e .env.schema.nvis-init-backup
cp .env.schema .env.schema.nvis-init-backup
```

## 7. Configure the schema

Replace `.env.schema` only after making the backup above:

```console
cat >.env.schema <<'EOF'
# @defaultSensitive=false
# @defaultRequired=false
# ---

# NVIDIA GitLab instance hostname.
# @public @required @type=domain
GITLAB_HOST="gitlab-master.nvidia.com"

# Non-empty username used for Git over HTTPS.
# @public @required @type=string(minLength=1)
GITLAB_USERNAME="oauth2"

# GitLab group access token used for Git and API operations.
# @sensitive @required @type=string(minLength=20)
GITLAB_TOKEN=
EOF
```

The two root decorators each appear exactly once. They make variables public
and optional by default; the item decorators then explicitly make all three
required and the token sensitive.

The hostname and username are public configuration. The token is sensitive,
required, and deliberately absent from the schema. No strict token-prefix rule
is used because it would be safe only if NVIDIA's self-managed GitLab instance
guaranteed that prefix for every group token.

## 8. Create the device-local secret file

If `.env.local` already exists, stop and use the
[rotation guide](how-to/rotate-group-token.md). For a new file:

```console
umask 077
printf '%s\n' 'GITLAB_TOKEN=varlock(prompt)' >.env.local
chmod 600 .env.local
npm exec -- varlock load
```

Varlock prompts with hidden input. Paste the token there, never into the shell
command. Varlock replaces `varlock(prompt)` with an encrypted
`varlock("local:...")` value tied to this device.

`.env.local` must not be shared or committed. Its encrypted payload is also
device-local material and is not intended to be copied to another machine.

## 9. Protect local-only files

Append each ignore entry only if it is absent:

```console
grep -qxF '.env.local' .gitignore 2>/dev/null || \
  printf '%s\n' '.env.local' >>.gitignore
grep -qxF 'node_modules/' .gitignore 2>/dev/null || \
  printf '%s\n' 'node_modules/' >>.gitignore
```

The ignore file documents which files are local-only and protects them if the
workspace is tracked now or later. Before committing from this directory,
always confirm that `.env.local` and `node_modules/` remain ignored.

## 10. Validate Varlock without revealing the token

```console
npm exec -- varlock load --agent
```

`--agent` produces transcript-safe JSON and redacts values marked sensitive.
Confirm the command succeeds and `GITLAB_TOKEN` is redacted. Never validate a
token with `echo`, `printenv`, `env`, shell tracing, or a raw Varlock output
format.

## 11. Test authenticated GitLab API access

Run the request inside `varlock run`. It prints only the HTTP status; process
substitution keeps the resolved token out of the curl argument list.

```console
npm exec -- varlock run --inject vars -- bash -c '
status=$(curl --silent --output /dev/null --write-out "%{http_code}" \
  --config <(printf "header = \"PRIVATE-TOKEN: %s\"\n" "$GITLAB_TOKEN") \
  "https://${GITLAB_HOST}/api/v4/user")
printf "GitLab /user HTTP %s\n" "$status"
test "$status" = 200
'
```

Expected success is `GitLab /user HTTP 200`. Unlike an endpoint that may be
publicly readable, `/api/v4/user` proves that GitLab accepted the token.

| Result | Meaning |
|---|---|
| `200` | GitLab authenticated the token |
| `401` | Token is missing, invalid, expired, or was not loaded correctly |
| `403` | GitLab authenticated the caller but denied the operation |
| Connection or TLS failure | Check VPN, network, hostname, proxy, and system trust |

Do not weaken TLS verification to work around a connection failure.

## 12. Verify token metadata and group role

The self-inspection endpoint returns metadata, not the token value. This script
prints only the state, expiry, scopes, and numeric group access level:

```console
npm exec -- varlock run --inject vars -- bash -c '
set -eu
tmp_user=$(mktemp)
tmp_token=$(mktemp)
trap '\''rm -f "$tmp_user" "$tmp_token"'\'' EXIT
header_config() {
  printf "header = \"PRIVATE-TOKEN: %s\"\n" "$GITLAB_TOKEN"
}
self_status=$(curl --silent --output "$tmp_token" --write-out "%{http_code}" \
  --config <(header_config) \
  "https://${GITLAB_HOST}/api/v4/personal_access_tokens/self")
if [ "$self_status" = 404 ]; then
  echo "Token self-inspection is unavailable; verify metadata in the approved GitLab UI."
  exit 2
fi
test "$self_status" = 200
jq '{active, revoked, expires_at, scopes}' "$tmp_token"
jq -e '\''
  .active == true and .revoked == false and
  (["api", "read_api", "read_repository", "write_repository"]
    - (.scopes // []) | length == 0)
'\'' "$tmp_token" >/dev/null
curl --silent --output "$tmp_user" --config <(header_config) \
  "https://${GITLAB_HOST}/api/v4/user"
user_id=$(jq -r .id "$tmp_user")
access_level=$(curl --silent --config <(header_config) \
  "https://${GITLAB_HOST}/api/v4/groups/401322/members/all/${user_id}" |
  jq -r .access_level)
printf "nvis-ova access level: %s\n" "$access_level"
test "$access_level" -eq 30
'
```

Confirm `active` is `true`, `revoked` is `false`, the expiration complies with
policy, all four expected scopes are present, and the access level is `30`
(Developer).

If `/personal_access_tokens/self` is unavailable on the installed GitLab
version, confirm the scopes, state, and expiry through the approved GitLab UI
or credential owner. Do not treat an unsupported endpoint as proof that the
metadata is correct.

## 13. Create `GIT_ASKPASS`

Git does not consume `GITLAB_TOKEN` merely because the variable exists. Create
an askpass program in the credential workspace, outside the project repository.
Back up an existing file instead of overwriting it:

```console
if [ -e gitlab-askpass.sh ]; then
  test ! -e gitlab-askpass.sh.nvis-init-backup
  cp -p gitlab-askpass.sh gitlab-askpass.sh.nvis-init-backup
fi
cat >gitlab-askpass.sh <<'EOF'
#!/bin/sh

case "$1" in
  *Username*|*username*)
    printf '%s\n' "${GITLAB_USERNAME:-oauth2}"
    ;;
  *Password*|*password*)
    printf '%s\n' "$GITLAB_TOKEN"
    ;;
  *)
    exit 1
    ;;
esac
EOF
chmod 700 gitlab-askpass.sh
```

The single-quoted `EOF` is important: the file contains literal variable
references, never resolved credentials. Do not put the token in a Git URL, Git
configuration, or credential-helper file.

## 14. Choose a project and test repository read access

From the credential workspace, run Git through Varlock with terminal prompting
disabled. `project_path` is the GitLab path relative to `nvis-ova`.
`project_dir` is the local clone location and can be anywhere on the
Omnistation.

```console
cd ~/git/nvis-ova
project_path="cluster-bringup" # replace with a path relative to nvis-ova
project_dir="$HOME/git/nvis-ova/$project_path" # or an existing clone elsewhere
repository_url="https://gitlab-master.nvidia.com/nvis-ova/${project_path}.git"
GIT_ASKPASS="$PWD/gitlab-askpass.sh" \
GIT_TERMINAL_PROMPT=0 \
npm exec -- varlock run --inject vars -- \
git ls-remote \
  "$repository_url" HEAD
```

For example, set `project_path=cluster-bringup`. The same check works for any
project path the token can read, including a project in a subgroup.

Success prints a commit ID followed by `HEAD`. `Authentication failed` normally
means the username/token pair, scope, or token state is wrong. A disabled
terminal prompt makes failures explicit instead of hanging for input.

## 15. Use an existing clone or clone the project

If `project_dir` already points to a clone, keep it in place. Otherwise, clone
the project through Varlock:

```console
if git -C "$project_dir" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  printf 'Using existing clone: %s\n' "$project_dir"
else
  mkdir -p "$(dirname "$project_dir")"
  GIT_ASKPASS="$PWD/gitlab-askpass.sh" \
  GIT_TERMINAL_PROMPT=0 \
  npm exec -- varlock run --inject vars -- \
  git clone \
    "$repository_url" \
    "$project_dir"
fi
```

This supports repositories cloned before Varlock was configured; they do not
need to be moved or cloned again. Inspect an existing clone's configured
remotes, if any, before using the group token with it.

## 16. Install the reusable Codex launcher

Create an owner-only launcher in the credential workspace. It finds the
workspace from its own location, so it works regardless of the caller's
current directory. Back up an existing launcher instead of overwriting it:

```console
cd ~/git/nvis-ova
if [ -e codex-varlock-yolo.sh ]; then
  test ! -e codex-varlock-yolo.sh.nvis-init-backup
  cp -p codex-varlock-yolo.sh codex-varlock-yolo.sh.nvis-init-backup
fi
cat >codex-varlock-yolo.sh <<'EOF'
#!/bin/sh
set -eu

workspace=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
askpass="$workspace/gitlab-askpass.sh"

test -f "$workspace/.env.schema" || {
  printf '%s\n' "Missing Varlock schema: $workspace/.env.schema" >&2
  exit 1
}
test -x "$askpass" || {
  printf '%s\n' "Missing executable askpass helper: $askpass" >&2
  exit 1
}
command -v npm >/dev/null 2>&1 || {
  printf '%s\n' 'npm is not installed or is not on PATH' >&2
  exit 1
}
command -v codex >/dev/null 2>&1 || {
  printf '%s\n' 'codex is not installed or is not on PATH' >&2
  exit 1
}

if [ "$#" -eq 0 ]; then
  set -- resume --last
fi

printf '%s\n' \
  'WARNING: Codex YOLO mode disables approvals and sandboxing.' \
  'Use only in a dedicated, externally isolated environment with trusted repository content.' \
  >&2

cd "$workspace"
exec env \
  GIT_ASKPASS="$askpass" \
  GIT_TERMINAL_PROMPT=0 \
  npm exec -- varlock run --path "$workspace" --inject vars -- \
  codex --dangerously-bypass-approvals-and-sandbox "$@"
EOF
chmod 700 codex-varlock-yolo.sh
sh -n codex-varlock-yolo.sh
```

Start a new Codex session in the selected project:

```console
~/git/nvis-ova/codex-varlock-yolo.sh -C "$project_dir"
```

Resume the latest session associated with that project:

```console
~/git/nvis-ova/codex-varlock-yolo.sh \
  -C "$project_dir" \
  resume --last
```

Arguments are forwarded to Codex. With no arguments, the launcher supplies
`resume --last` from the credential workspace; use `-C` when targeting a
project repository.

The launcher contains paths and literal variable names, never the token. It
uses `--path` to resolve the credential workspace, and `--inject vars` to omit
the additional serialized Varlock environment blob. The real token is still
available to Codex and every child process it launches.

`--dangerously-bypass-approvals-and-sandbox` (also called `--yolo`) disables
Codex approvals and sandboxing. The launcher prints a warning on every run. Use
it only in a dedicated, externally isolated environment with trusted
repository content. Varlock is not a substitute for that isolation.

## 17. Verify the project repository

Run repository commands against `project_dir`:

```console
git -C "$project_dir" rev-parse --show-toplevel
git -C "$project_dir" remote -v
git -C "$project_dir" branch --show-current
git -C "$project_dir" log -1 --oneline
git -C "$project_dir" status --short
```

Confirm the expected work-tree root, review any configured remotes, and verify
that the repository has an existing commit. A pre-existing clone can use any
remote name, default branch, or transport. Preserve any local changes shown by
the final status command.

## 18. Test feature-branch write access

From the credential workspace, use a dry-run push through Varlock:

```console
GIT_ASKPASS="$PWD/gitlab-askpass.sh" \
GIT_TERMINAL_PROMPT=0 \
npm exec -- varlock run --inject vars -- \
git -C "$project_dir" \
  push --dry-run \
  "$repository_url" \
  HEAD:refs/heads/<username>-token-access-check
```

`--dry-run` prevents the branch from being created. Success verifies
feature-branch push authentication, but neither grants nor tests permission to
bypass protected-branch rules.

If Git says `not a git repository`, verify `project_dir`. That message is not a
token-permission failure.

## What you built

You now have all of the following:

- The group token is encrypted in the device-local `.env.local` file.
- `varlock load --agent` validates configuration with the token redacted.
- `/api/v4/user` returns HTTP `200`.
- Token state, expiry, and all four expected scopes are confirmed.
- The token identity has Developer group access.
- `git ls-remote` proves repository read access.
- A dry-run feature-branch push proves feature-branch write access.
- Codex launches through Varlock with the runtime security boundary understood.
- The owner-only launcher resumes the last credential-workspace session by
  default and forwards explicit Codex arguments when supplied.
- Each cloned project remains an independent Git repository with its existing
  history, and the launcher can target any of them with `-C`.

For rotation, repeatable verification, or failure diagnosis, continue with the
[task-oriented guides](README.md).
