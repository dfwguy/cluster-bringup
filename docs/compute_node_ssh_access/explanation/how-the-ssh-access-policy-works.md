# How the SSH access policy works

The policy gives a running Slurm job priority over unmanaged SSH sessions while
still allowing approved users to connect to an idle compute node.

## The account checks run in order

The PAM account stack makes three decisions:

1. `pam_slurm_adopt` admits `root` or a user whose connection can be adopted
   into a local job. A successful adoption ends the account checks.
2. If the user has no local job, `check_node_busy.sh` runs `scontrol listpids`.
   Any Slurm-managed process makes the node busy and denies the login.
3. On an idle node, `pam_access` applies the site's normal rules from
   `/etc/security/access.conf`.

The order matters. Checking `pam_access` first could admit an unmanaged session
on a busy node. Checking node activity first could reject the owner of the job
that made the node busy.

| Connection state | `pam_slurm_adopt` | Helper | Result |
|---|---|---|---|
| `root` or the owner of a local job | success; `success=done` stops the stack | Not run | Allowed and, for a job owner, adopted into the job's external step |
| User has no local job; no local Slurm job steps exist | `ignore` | Returns `0` | `pam_access` decides |
| User has no local job; another job has local Slurm steps | `ignore` | Returns non-zero | Denied by `pam_exec requisite` |
| Slurm adoption or activity lookup fails unexpectedly | `default=die`, or helper non-zero | Not applicable or denied | Denied |

## The activity check fails closed

`scontrol listpids` has an important, expected idle-node response: it writes
`No job steps exist on this node.` and exits with status `1`. The helper maps
only that exact result to status `0`, allowing the idle-node fallback.

When job steps exist, `scontrol listpids` exits successfully and returns its
PID/JOBID table; the helper returns non-zero and blocks the unmanaged login.
A missing Slurm module, an unavailable `scontrol`, a different non-zero
response, or unexpected successful output all deny access.

For each denial, the helper writes a concise reason to the system journal under
the `check_node_busy` tag. This is necessary because `pam_exec` is configured
as `quiet`, which intentionally suppresses helper output during an SSH login.

The helper uses the cluster's stable `scontrol` and `SLURM_CONF` paths directly.
PAM executes `pam_exec` as root, so sourcing the interactive Environment
Modules setup is unsafe: that site initialization can exit the helper before it
reports a denial reason.

Failing closed prevents a broken Slurm check from silently turning a compute
node into a general-purpose SSH host.

## What “busy” means

This policy defines a busy node as one with a process in a local Slurm step. An
allocation with no current step processes is treated as idle. It grants a job
owner an exception before this node-wide check runs.

PAM evaluates the policy only when a connection starts. It does not disconnect
a user who was admitted while the node was idle and remains connected when a
job starts later.
