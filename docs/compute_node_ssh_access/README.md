# Compute-node SSH access

Documentation for allowing Slurm job owners to SSH to compute nodes while
blocking new unmanaged logins on nodes that have Slurm-managed processes.

This documentation follows the [Diátaxis](https://diataxis.fr/) framework.

| Document | Type | Use it when |
|---|---|---|
| [Install `pam_slurm_adopt` in a BCM software image](how-to/install-pam-slurm-adopt-in-bcm-image.md) | How-to | You need to install matching Slurm packages and update one test node |
| [Test `pam_slurm_adopt` on one compute node](how-to/test-pam-slurm-adopt-on-a-compute-node.md) | How-to | You need to prove a job-owner SSH session joins `step_extern` |
| [Gate SSH access on Slurm activity](how-to/gate-ssh-access-on-slurm-activity.md) | How-to | You need to add the final idle-node SSH access policy |
| [How the SSH access policy works](explanation/how-the-ssh-access-policy-works.md) | Explanation | You need to understand the policy decisions and failure behavior |

## Scope and assumptions

- The target is a managed compute node running `slurmd`, not a login or
  client-only node.
- Complete the installation and adoption-test how-tos before enabling the
  final SSH access policy.
- The policy gates new SSH logins. It does not terminate sessions admitted
  before a job starts.
- Busy means that `scontrol listpids` reports a Slurm-managed process. An
  allocation with no current step processes is treated as idle.
