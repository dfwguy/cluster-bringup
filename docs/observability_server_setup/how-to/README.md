# How-to guides: observability server setup

Choose a task for an existing standalone Slurm client. For the first setup,
start with the [tutorial](../tutorial.md).

| Guide | Goal |
|---|---|
| [mount-cm-shared.md](mount-cm-shared.md) | Mount BCM's `/cm/shared`, and set up `/cluster` as shared working space |
| [set-up-munge.md](set-up-munge.md) | Install munge and install the cluster's key locally |
| [install-slurm-binaries.md](install-slurm-binaries.md) | Get Slurm client binaries on without BCM repo access |
| [enable-job-submission.md](enable-job-submission.md) | Supply the SPANK plugin `srun` and `sbatch` refuse to start without |
| [install-enroot.md](install-enroot.md) | Install the Enroot packages required by Pyxis |
| [configure-enroot.md](configure-enroot.md) | Configure NGC credentials and per-user Enroot storage for container jobs |
| [align-uids.md](align-uids.md) | Match local UIDs to cluster UIDs so `squeue` returns data |
| [add-cmods-user.md](add-cmods-user.md) | Provision the `cmods` admin account on a new node, UID-aligned |
| [persist-environment.md](persist-environment.md) | Make `sinfo` work after reboot, under `sudo`, and in cron |
| [set-up-dns.md](set-up-dns.md) | Resolve cluster hostnames via the head node's DNS |
| [distribute-ssh-keys.md](distribute-ssh-keys.md) | Give users passwordless SSH to managed nodes via NFS home |
| [set-up-clush.md](set-up-clush.md) | Fan out commands across nodes, grouped by Slurm state |
| [troubleshoot.md](troubleshoot.md) | Diagnose a failing `sinfo` / `squeue` |


Return to the [guide overview](../README.md).
