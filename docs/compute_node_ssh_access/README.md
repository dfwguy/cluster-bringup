# Compute-node SSH access

Documentation for allowing Slurm job owners to SSH to compute nodes while
blocking new unmanaged logins on nodes that have Slurm-managed processes.

This documentation follows the [Diátaxis](https://diataxis.fr/) framework.

| Document | Type | Use it when |
|---|---|---|
| [Install the Slurm SSH gate on one compute node](how-to/install-ssh-gate-on-one-compute-node.md) | How-to | You need to install and test the complete setup on one drained node |
| [Install the Slurm SSH gate on the compute-node fleet](how-to/install-ssh-gate-on-the-compute-node-fleet.md) | How-to | You need to promote the tested setup to compute-node batches |
| [Verify the Slurm SSH gate](how-to/verify-slurm-ssh-gate.md) | How-to | You need to validate either a single node or a fleet rollout batch |
| [How the SSH access policy works](explanation/how-the-ssh-access-policy-works.md) | Explanation | You need to understand the policy decisions and failure behavior |

## Scope and assumptions

- The target is a managed compute node running `slurmd`, not a login or
  client-only node.
- Complete the one-node installation and verification before a fleet rollout.
- The policy gates new SSH logins. It does not terminate sessions admitted
  before a job starts.
- Busy means that `scontrol listpids` reports a Slurm-managed process. An
  allocation with no current step processes is treated as idle.
