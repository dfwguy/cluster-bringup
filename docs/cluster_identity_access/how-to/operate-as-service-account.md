# How to operate as `cmods` or `cmods-automation`

Use this procedure when an authorized operator must inspect, run, or recover
NVIS Rack Status or an automated test without logging in directly as a shared
account.

`cmods` runs NVIS Rack Status. `cmods-automation` runs automatically executed
tests. Both run their workloads through systemd services and Docker containers
on the app-server/slogin server. Choose the identity that normally runs the
work; do not use `root` merely for convenience.

## 1. Connect using your individual account

Log in to the approved app-server or slogin server using your own SSH key:

```console
ssh <your-individual-account>@<app-server-or-slogin>
```

Confirm your identity before elevating:

```console
id
```

## 2. Check that you are authorized to assume the target identity

Use `sudo -l` to see the commands and target users permitted to your account:

```console
sudo -l
```

If the required target user or command is not allowed, stop and use the access
request process. Do not change ownership, add a password, share keys, or use
another person's account to bypass the restriction.

## 3. Assume the least-privileged required identity

For a single approved command, preserve the audit boundary by naming the
target user explicitly:

```console
sudo -u cmods -- <approved-rack-status-command>
```

For an automatically executed test, use:

```console
sudo -u cmods-automation -- <approved-automation-command>
```

Use an interactive shell only when the recovery procedure requires it:

```console
sudo -iu cmods
```

or:

```console
sudo -iu cmods-automation
```

Immediately verify the effective identity:

```console
id; whoami
```

## 4. Operate and record the result

Run the documented systemd or Docker command for the Rack Status process or
automated test. Keep service files, logs, containers, and output owned by their
intended service identity. Avoid starting automated tests as `cmods` or a human
account, or Rack Status as `cmods-automation`, because that breaks the intended
runtime and audit boundaries.

Record the incident/change reference, your individual login identity, target
identity, commands run, and outcome. Exit the service shell when finished.

## 5. Escalate a failed access check safely

If `sudo` prompts unexpectedly, fails, or the target account is absent, do not
set a password or edit `/etc/sudoers` ad hoc. Capture the non-secret error and
ask the BCM/platform administrators to repair the account or the approved sudo
policy. A service-account password is not a recovery mechanism in this model.
