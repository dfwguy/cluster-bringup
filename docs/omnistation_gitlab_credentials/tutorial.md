# Tutorial: use a Varlock GitLab group token on an Omnistation

By the end of this tutorial, a device-local encrypted group access token can
authenticate to the NVIDIA GitLab API, read the existing `cluster-bringup`
repository, and dry-run a feature-branch push. Codex will run through Varlock,
and `cluster-bringup` will retain its existing Git history as an independent
child repository.

The commands were validated on 2026-09-09 with Varlock `1.18.0`, Node.js
`22.23.2`, npm `10.9.8`, Codex CLI `0.153.4`, Git `2.43.0`, and curl `8.5.0`.
Varlock `1.18.0` was also the current npm release on that date.

## 1. Establish the terminology

`nvis-ova` is a **GitLab group**. It is not a Linux or Unix user group. A group
access token belongs to that GitLab group and can access permitted projects in
the group. `cluster-bringup` is one existing GitLab project and Git repository
inside `nvis-ova`; this tutorial does not create another project.

GitLab is the remote hosting service. Git is the local version-control tool.
Varlock stores and resolves configuration and secrets on the Omnistation. An
Omnistation is the machine on which these commands run.

The group workspace, `~/git/nvis-ova`, is simply a directory the user creates.
GitLab, Git, Varlock, and Omnistation do not create it automatically.

## 2. Understand the directory layout

The completed layout is:

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
└── cluster-bringup/
    └── .git/
```

`~/git/nvis-ova` is the Varlock credential workspace. It is intentionally not a
Git repository: do not run `git init` there. The child `cluster-bringup`
directory is the cloned Git repository, and only it owns the project's Git
history. Files above the child directory cannot enter its commits.

This parent workspace is an NVIS convention that lets group credentials exist
before a repository is cloned and supports more than one repository in the
same GitLab group. It is not a universal Varlock layout. Ordinary Varlock
applications can place `.env.schema` directly in their application repository.

## 3. Obtain the GitLab group access token

1. Open the `NVIS-OVA` group itself in GitLab.
2. Select **Group Settings > Access tokens**.
3. Confirm the breadcrumb names the group, not `cluster-bringup` or another
   individual project.
4. Create or obtain a group access token with Developer-or-higher access,
   according to the applicable group policy.
5. Select all four expected NVIS scopes: `api`, `read_api`, `read_repository`,
   and `write_repository`.
6. Choose an expiration date that complies with NVIDIA policy.
7. Copy the token when GitLab displays it.
8. Store it securely immediately. GitLab does not display it again.

Creating a group access token normally requires the Group Owner role. If you
are not an Owner, obtain it through the group's approved owner or credential-
provisioning process. Do not create a project access token from the
`cluster-bringup` project for this workflow.

## 4. Check the Omnistation prerequisites

For the npm installation, Node.js must be version 22 or newer. Confirm Node.js,
npm, and Codex are installed:

```console
node --version
npm --version
codex --version
```

Connect to the NVIDIA VPN or approved network path, then verify DNS and TLS
reachability without disabling certificate checks:

```console
curl --head --silent --show-error \
  https://gitlab-master.nvidia.com/users/sign_in >/dev/null
```

## 5. Create the group workspace

Create the directory yourself and enter it:

```console
mkdir -p ~/git/nvis-ova
cd ~/git/nvis-ova
```

This directory is not created by another tool. Do not initialize it as a Git
repository.

## 6. Install and pin Varlock

Protect a pre-existing `package.json`; initialize npm only when it is absent:

```console
test -e package.json || npm init -y
npm install --save-exact varlock@1.18.0
npm exec -- varlock --version
```

The final command must print `1.18.0`. The exact dependency and generated
`package-lock.json` prevent a future install from silently selecting a new
Varlock release.

## 7. Initialize Varlock

Run Varlock's initialization command from the parent workspace:

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

## 8. Configure the schema

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

## 9. Create the device-local secret file

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

## 10. Protect local-only files

Append each ignore entry only if it is absent:

```console
grep -qxF '.env.local' .gitignore 2>/dev/null || \
  printf '%s\n' '.env.local' >>.gitignore
grep -qxF 'node_modules/' .gitignore 2>/dev/null || \
  printf '%s\n' 'node_modules/' >>.gitignore
```

The parent workspace is not a Git repository, but the ignore file documents
which files are local-only and prevents accidental inclusion if the workspace
is later inspected by tooling.

## 11. Validate Varlock without revealing the token

```console
npm exec -- varlock load --agent
```

`--agent` produces transcript-safe JSON and redacts values marked sensitive.
Confirm the command succeeds and `GITLAB_TOKEN` is redacted. Never validate a
token with `echo`, `printenv`, `env`, shell tracing, or a raw Varlock output
format.

## 12. Test authenticated GitLab API access

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

## 13. Verify token metadata and group role

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
test "$access_level" -ge 30
'
```

Confirm `active` is `true`, `revoked` is `false`, the expiration complies with
policy, and all four expected scopes are present. Access level `30` is
Developer; `40` is Maintainer and `50` is Owner.

If `/personal_access_tokens/self` is unavailable on the installed GitLab
version, confirm the scopes, state, and expiry through the approved GitLab UI
or credential owner. Do not treat an unsupported endpoint as proof that the
metadata is correct.

## 14. Create `GIT_ASKPASS`

Git does not consume `GITLAB_TOKEN` merely because the variable exists. Create
an askpass program in the parent workspace, outside `cluster-bringup`. Back up
an existing file instead of overwriting it:

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

## 15. Test repository read access

From the parent workspace, run Git through Varlock with terminal prompting
disabled:

```console
cd ~/git/nvis-ova
GIT_ASKPASS="$PWD/gitlab-askpass.sh" \
GIT_TERMINAL_PROMPT=0 \
npm exec -- varlock run --inject vars -- \
git ls-remote \
  https://gitlab-master.nvidia.com/nvis-ova/cluster-bringup.git HEAD
```

Success prints a commit ID followed by `HEAD`. `Authentication failed` normally
means the username/token pair, scope, or token state is wrong. A disabled
terminal prompt makes failures explicit instead of hanging for input.

## 16. Install the reusable Codex launcher

Create an owner-only launcher in the parent workspace. It finds the workspace
from its own location, so it works regardless of the caller's current
directory. Back up an existing launcher instead of overwriting it:

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

Run it with no arguments to replace the long `resume --last` command:

```console
~/git/nvis-ova/codex-varlock-yolo.sh
```

With no arguments, the launcher supplies `resume --last`. Any arguments you do
supply replace that default and are forwarded to Codex. For example, start a
new session in an existing child repository with:

```console
~/git/nvis-ova/codex-varlock-yolo.sh \
  -C ~/git/nvis-ova/cluster-bringup
```

The launcher contains paths and literal variable names, never the token. It
uses `--path` to resolve the parent workspace, and `--inject vars` to omit the
additional serialized Varlock environment blob. The real token is still
available to Codex and every child process it launches.

`--dangerously-bypass-approvals-and-sandbox` (also called `--yolo`) disables
Codex approvals and sandboxing. The launcher prints a warning on every run. Use
it only in a dedicated, externally isolated environment with trusted
repository content. Varlock is not a substitute for that isolation.

## 17. Clone the existing `cluster-bringup` project

Start a new Varlock-launched Codex session with a prompt to clone the existing
project:

```console
~/git/nvis-ova/codex-varlock-yolo.sh \
  'Clone the existing nvis-ova/cluster-bringup GitLab repository into ~/git/nvis-ova/cluster-bringup and preserve its history.'
```

The agent should run:

```console
git clone \
  https://gitlab-master.nvidia.com/nvis-ova/cluster-bringup.git \
  "$HOME/git/nvis-ova/cluster-bringup"
```

This clones the existing GitLab project and preserves its history. Do not
create a new GitLab project, run `git init` in the parent, or start a new and
unrelated history.

## 18. Verify the cloned repository

All Git commands from this point must run inside `cluster-bringup` or use
`git -C`:

```console
git -C ~/git/nvis-ova/cluster-bringup remote get-url origin
git -C ~/git/nvis-ova/cluster-bringup \
  symbolic-ref --short refs/remotes/origin/HEAD
git -C ~/git/nvis-ova/cluster-bringup branch --show-current
git -C ~/git/nvis-ova/cluster-bringup log -1 --oneline
git -C ~/git/nvis-ova/cluster-bringup status --short
```

Expect the HTTPS origin, `origin/main`, the current branch, an existing project
commit, and no output from the final command for a clean tree.

## 19. Test feature-branch write access

While still inside the Varlock-launched environment, use a dry-run push:

```console
git -C ~/git/nvis-ova/cluster-bringup \
  push --dry-run \
  origin \
  HEAD:refs/heads/<username>-token-access-check
```

`--dry-run` prevents the branch from being created. Success verifies
feature-branch push authentication, but neither grants nor tests permission to
bypass protected-branch rules.

If Git says `not a git repository`, the command used the parent workspace or
another wrong directory. That message is not a token-permission failure.

## 20. Confirm the successful state

You now have all of the following:

- The group token is encrypted in the device-local `.env.local` file.
- `varlock load --agent` validates configuration with the token redacted.
- `/api/v4/user` returns HTTP `200`.
- Token state, expiry, and all four expected scopes are confirmed.
- The token identity has Developer-or-higher group access.
- `git ls-remote` proves repository read access.
- A dry-run feature-branch push proves feature-branch write access.
- Codex launches through Varlock with the runtime security boundary understood.
- The owner-only launcher resumes the last parent-workspace session by default
  and forwards explicit Codex arguments when supplied.
- `cluster-bringup` is an independent child Git repository with its existing
  history.

For rotation, repeatable verification, or failure diagnosis, continue with the
[task-oriented guides](README.md).
