# How to gate SSH access on Slurm activity

Use this procedure to allow `root` and users with a local Slurm job to connect
to a compute node. Other users can connect only when the node is idle and
`/etc/security/access.conf` allows them.

## Prerequisites

- Install `pam_slurm_adopt.so` from the **same Slurm 25.05 build as
  `slurmd`**. Do not install Ubuntu's `libpam-slurm-adopt` or
  `libslurm40t64` for this cluster: they are Slurm 23.11 and cannot safely use
  this site's 25.05 plugins. In particular, do not try to repair a 23.11 PAM
  module by setting `PluginDir` to `/cm/local/apps/slurm/25.05/lib64/slurm`.

  On the Slurm build host, use the already-configured source/build tree that
  produced `/cm/local/apps/slurm/25.05/sbin/slurmd`. Build and install only
  the PAM contribution from that tree:

  ```console
  cd <slurm-25.05-build>/contribs/pam_slurm_adopt
  make
  sudo make install
  ```

  The Slurm build must have been configured with `--with-pam_dir` set to the
  PAM module directory for the target image. Build on (or cross-compile for)
  that target architecture. Determine the module directory from an installed
  PAM module rather than guessing it:

  ```console
  pam_dir=$(dirname "$(readlink -f "$(find /lib /usr/lib -type f -name pam_unix.so -print -quit)")")
  printf '%s\n' "$pam_dir"
  # Expected on this node: /usr/lib/aarch64-linux-gnu/security
  ```

  If the existing 25.05 build was configured for another PAM directory,
  reconfigure/rebuild the **site's 25.05 Slurm build** with, for example:

  ```console
  ./configure <the existing site build options> \
    --with-pam_dir=/usr/lib/aarch64-linux-gnu/security
  ```

  Then run `make` and `sudo make install` in
  `contribs/pam_slurm_adopt`. Preserve all existing site configure options;
  this is not a standalone Ubuntu-package build.

  Confirm that the installed module and its linked Slurm library both come
  from the site 25.05 release before editing `/etc/pam.d/sshd`:

  ```console
  pam_adopt=$(find /lib /usr/lib -type f -name pam_slurm_adopt.so -print -quit)
  printf 'module: %s\n' "$pam_adopt"
  ldd "$pam_adopt" | grep libslurm
  ```

  The `ldd` output must resolve `libslurm` from
  `/cm/local/apps/slurm/25.05/lib64`, not an Ubuntu `/lib` or `/usr/lib`
  package. Repeat this validation on the image and on a running node; a
  locally installed 23.11 module must be removed or replaced before enabling
  the PAM rule.

- Ensure the PAM process can find the shared Slurm configuration. `slurmd`'s
  `SLURM_CONF` environment is not inherited by `sshd`, and an interactive
  `module load slurm` does not help PAM. First verify the shared configuration:

  ```console
  sudo env -i \
    PATH=/cm/local/apps/slurm/current/bin:/usr/bin:/bin \
    SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf \
    /cm/local/apps/slurm/current/bin/scontrol show config >/dev/null \
    && echo "shared Slurm configuration works"
  ```

  Then make it available to the SSH daemon and its PAM children:

  ```console
  sudo install -d -m 0755 /etc/systemd/system/ssh.service.d
  printf '%s\n' \
    '[Service]' \
    'Environment=SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf' \
    | sudo tee /etc/systemd/system/ssh.service.d/slurm.conf >/dev/null
  sudo sshd -t
  sudo systemctl daemon-reload
  sudo systemctl restart ssh.service
  sudo systemctl show ssh.service -p Environment
  ```

  Keep an existing root session open until a new SSH login succeeds. The
  resulting environment must show the shared `SLURM_CONF` path.

- Verify the site module, plugins, and daemon are all Slurm `25.05`:

  ```console
  /cm/local/apps/slurm/current/bin/scontrol --version
  sudo find /cm/local/apps/slurm/25.05/lib64/slurm -maxdepth 1 -type f \
    \( -name task_cgroup.so -o -name proctrack_cgroup.so \) -ls
  ```

- `pam_slurm_adopt.so` and its Slurm containment requirements are configured:

  ```console
  scontrol show config | grep -Ei '^(PrologFlags|TaskPlugin|ProctrackType)'
  ```

  Require `PrologFlags=contain`, `TaskPlugin=task/cgroup`, and
  `ProctrackType=proctrack/cgroup` before enabling adoption.
- SSH uses PAM, and `pam_systemd.so` is disabled in PAM files included by
  `sshd`. Check the active files with:

  ```console
  sudo grep -RniE '^[[:space:]]*[^#].*pam_systemd\.so' /etc/pam.d
  ```
- The shared Slurm configuration and `scontrol` binary are available at
  `/cm/shared/apps/slurm/etc/slurm/slurm.conf` and
  `/cm/local/apps/slurm/current/bin/scontrol`. The busy-node helper uses these
  paths directly because PAM executes it as root; it must not source the
  interactive Environment Modules setup.
- `/etc/security/access.conf` contains the intended idle-node access rules.

## 1. Install the busy-node helper

From the repository checkout, copy the
[`check_node_busy.sh` helper](../../../scripts/check_node_busy.sh) to the
compute node:

```console
scp scripts/check_node_busy.sh <admin-user>@<compute-node>:check_node_busy.sh
```

On the compute node, install the local copied file. Do not include the
repository's `scripts/` prefix here:

```console
sudo install -o root -g root -m 0755 check_node_busy.sh \
    /usr/local/sbin/check_node_busy.sh
```

## 2. Test `pam_slurm_adopt` in isolation

Keep the existing `account` entries in `/etc/pam.d/sshd`. For the initial
adoption test, add only this entry after the normal account includes:

```pam
account [success=done ignore=ignore default=die] pam_slurm_adopt.so action_no_jobs=ignore action_adopt_failure=deny action_generic_failure=deny
```

Do **not** add `pam_exec` or `pam_access` yet. Their decisions are independent
of adoption and can hide an adoption failure. Test an SSH login from the owner
of a real allocation, then verify the new shell belongs to the job's
`step_extern` cgroup as described below.

## 3. Add the idle-node policy

After adoption works in isolation, add these entries immediately after the
`pam_slurm_adopt.so` entry:

```pam
account requisite pam_exec.so quiet /usr/local/sbin/check_node_busy.sh
account required  pam_access.so
```

Keep this order and these control flags. Check included PAM files for an earlier
`account sufficient` entry, which could return before this policy runs.

The first rule deliberately bypasses the helper for `root` and for a user whose
SSH session is adopted into that user's local job. `action_no_jobs=ignore`
makes users without a local job continue to the helper, which permits an idle
node and rejects a node with other Slurm job steps.

An exit status of `1` from `check_node_busy.sh` is an intentional login denial
when the node has Slurm job steps. If the node is expected to be idle, run the
deployed helper directly before testing SSH:

```console
sudo /usr/local/sbin/check_node_busy.sh
echo $?
```

The helper writes the reason for every denial to the journal without logging
job PIDs. Inspect those messages with:

```console
sudo journalctl -t check_node_busy -n 50 --no-pager
```

## 4. Test on one compute node

Keep an existing root session open and test on one drained compute node first.
Run the helper on an idle node:

```console
sudo /usr/local/sbin/check_node_busy.sh
echo $?
```

The result must be `0`. Start a Slurm job on the node, run the helper again, and
confirm that it returns `1`.

The helper intentionally treats this raw Slurm result as an idle node and
returns `0` itself:

```console
/cm/local/apps/slurm/current/bin/scontrol listpids 2>&1
# No job steps exist on this node.
echo $?
# 1
```

Any other `scontrol` error is fail-closed and causes the helper to return `1`.

Follow logs during each SSH test:

```console
sudo journalctl -f -o short-iso | grep --line-buffered -Ei \
  'sshd|pam_slurm_adopt|slurmd|pam_exec|check_node_busy'
```

To diagnose adoption itself, temporarily append `log_level=debug5` to the
`pam_slurm_adopt.so` line, reproduce one login, collect the logs, and remove
the option. A DNS-SRV lookup failure means `SLURM_CONF` was not visible to PAM.

For the final adoption test, connect from a login node as the owner of a real
allocation. In the new SSH shell, confirm that it belongs to that job's Slurm
cgroup (normally its `step_extern` cgroup):

```console
echo "job=$SLURM_JOB_ID shell=$$"
cat /proc/$$/cgroup
```

A successful SSH login by itself does not prove adoption; the cgroup membership
does.

From a second terminal, test these SSH connections:

| Situation | Expected result |
|---|---|
| `root` | Login succeeds |
| User owns a local job | Login succeeds and is adopted into the job's external step |
| User owns no local job; node has Slurm-managed PIDs | Login fails |
| User owns no local job; node has no Slurm-managed PIDs; `pam_access` allows | Login succeeds |
| User owns no local job; node has no Slurm-managed PIDs; `pam_access` denies | Login fails |

Roll out the PAM change to the remaining compute nodes only after every test
passes.
