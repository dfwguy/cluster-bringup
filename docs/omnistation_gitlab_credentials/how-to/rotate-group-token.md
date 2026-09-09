# How to rotate an NVIS GitLab group token

Use this procedure when a group token is expiring, has been revoked, or must be
replaced. It preserves the old encrypted value until the replacement passes
validation.

## Obtain the replacement

A GitLab Group Owner must rotate the existing group token or create its
replacement through the approved process. Select the Developer role
and all four NVIS scopes: `api`, `read_api`, `read_repository`, and
`write_repository`. Apply an expiration date that complies with NVIDIA policy.

Copy the new token when GitLab displays it and store it immediately. Never put
it in a shell command, Git URL, Git configuration, or chat transcript.

## Replace the encrypted value

Work in the credential workspace, not a project repository. Back up the
existing device-local payload before changing it:

```console
cd ~/git/nvis-ova
backup=".env.local.pre-rotation.$(date -u +%Y%m%dT%H%M%SZ)"
cp -p .env.local "$backup"
chmod 600 "$backup"
```

Replace only the token resolver, preserving any other local variables:

```console
if grep -q '^GITLAB_TOKEN=' .env.local; then
  sed -i 's/^GITLAB_TOKEN=.*/GITLAB_TOKEN=varlock(prompt)/' .env.local
else
  printf '%s\n' 'GITLAB_TOKEN=varlock(prompt)' >>.env.local
fi
chmod 600 .env.local
npm exec -- varlock load
```

Enter the replacement through Varlock's hidden prompt. It writes a new
device-local encrypted value back to `.env.local`.

## Validate before retiring the old token

Run the [GitLab access verification](verify-gitlab-access.md). Confirm the token
is active and unrevoked, its expiration is acceptable, every expected scope is
present, group access is at least `30`, repository reads succeed, and a dry-run
feature-branch push succeeds.

After successful validation, remove the local backup and ask the credential
owner to revoke the superseded token if rotation did not revoke it
automatically:

```console
rm -- "$backup"
```

The backup contains device-local encrypted credential material. Keep it mode
`600`, never copy or commit it, and do not retain it after validation.
