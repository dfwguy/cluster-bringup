# How to gate SSH access on Slurm activity

Use this procedure after completing [install `pam_slurm_adopt` in a BCM
software image](install-pam-slurm-adopt-in-bcm-image.md) and [test
`pam_slurm_adopt` on one compute node](test-pam-slurm-adopt-on-a-compute-node.md).
It allows root and owners of local Slurm jobs to connect, while allowing other
users only when the node is idle and `/etc/security/access.conf` permits them.

## Prerequisites

- The matching `pam_slurm_adopt.so`, `task_cgroup.so`, and
  `proctrack_cgroup.so` are installed on the node.
- `PrologFlags=contain`, `TaskPlugin=task/cgroup`, and
  `ProctrackType=proctrack/cgroup` were enabled before the jobs being tested
  started.
- `pam_systemd.so` is disabled in PAM files included by `sshd`:

  ```console
  sudo grep -RniE '^[[:space:]]*[^#].*pam_systemd\.so' /etc/pam.d
  ```

## 1. Install the busy-node helper

From the repository checkout, copy the helper to the compute node, then
install the copied local file:

```console
scp scripts/check_node_busy.sh <admin-user>@<compute-node>:check_node_busy.sh
sudo install -o root -g root -m 0755 check_node_busy.sh \
  /usr/local/sbin/check_node_busy.sh
```

The helper uses the fixed site `scontrol` and `SLURM_CONF` paths. It must not
source `/etc/profile.d/modules.sh`, because PAM executes it as root.

## 2. Add the account policy

Add these rules after the normal account includes in `/etc/pam.d/sshd`:

```pam
account [success=done ignore=ignore default=die] pam_slurm_adopt.so action_no_jobs=ignore action_adopt_failure=deny action_generic_failure=deny
account requisite pam_exec.so quiet /usr/local/sbin/check_node_busy.sh
account required  pam_access.so
```

`pam_slurm_adopt` must be in the `account` stack; do not add a second `session
... pam_slurm_adopt.so` line or a `conf=` option. The `SLURM_CONF` entry in
`/etc/default/ssh`, installed with the image, provides the Slurm configuration
path.

The order is deliberate: a job owner is adopted first; a user with no local
job falls through to the helper; `pam_access` decides only for an idle node.

## 3. Validate the final policy

On an idle node the helper must return `0` even though raw `scontrol listpids`
returns `1` with its expected idle response:

```console
sudo /usr/local/sbin/check_node_busy.sh
echo $?

/cm/local/apps/slurm/current/bin/scontrol listpids 2>&1
echo $?
```

Start a Slurm job on the node and confirm the helper returns `1`. Inspect
intentional helper denials with:

```console
sudo journalctl -t check_node_busy -n 50 --no-pager
```

Test from another terminal:

| Situation | Expected result |
|---|---|
| root | Login succeeds |
| Owner of a local job | Login succeeds and is adopted into `step_extern` |
| No local job; node has Slurm-managed PIDs | Login fails |
| No local job; node is idle; `pam_access` allows | Login succeeds |
| No local job; node is idle; `pam_access` denies | Login fails |

Roll out only after every case succeeds on the test node.
