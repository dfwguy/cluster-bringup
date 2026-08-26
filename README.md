# nvis-ova-scripts

Scripts and documentation for NVIS OVA infrastructure.

## Documentation

The client guides cover giving a standalone (non-BCM-managed) Ubuntu host
access to a BCM cluster. The compute-node guide covers SSH access policy on
the managed cluster itself.

| Guide | Gives you | Talks to |
|---|---|---|
| [docs/observability_server_setup/](docs/observability_server_setup/) | `sinfo`, `squeue`, `sacct` — a read-only Slurm client, plus `clush` fan-out | Slurm controller, TCP 6817, munge + matching UID |
| [docs/cmsh_setup/](docs/cmsh_setup/) | `cmsh` — the interactive BCM management shell | CMDaemon, TCP 8081, X.509 client certificate |
| [docs/compute_node_ssh_access/](docs/compute_node_ssh_access/) | Job-aware SSH admission on compute nodes, with an idle-node fallback | Local PAM stack, `pam_slurm_adopt`, and `scontrol` |
| [docs/cluster_identity_access/](docs/cluster_identity_access/) | Individual, passwordless cluster identities and service-account operations | BCM, SSH public keys, `cmods`, and controlled `sudo` |

### Complete documentation index

#### Cluster identity and automation access

- [Overview](docs/cluster_identity_access/README.md)
- [Tutorial: provision a person for passwordless cluster access](docs/cluster_identity_access/tutorial.md)
- [How to operate as `cmods`](docs/cluster_identity_access/how-to/operate-as-service-account.md)
- [Explanation: why identities are separate](docs/cluster_identity_access/explanation/identity-boundaries.md)
- [Reference: cluster access model](docs/cluster_identity_access/reference/access-model.md)

#### `cmsh` setup

- [Overview: running `cmsh` from a non-BCM host](docs/cmsh_setup/README.md)
- [Tutorial: connect `cmsh` from a non-BCM host](docs/cmsh_setup/tutorial.md)
- [How to download BCM packages for an offline install](docs/cmsh_setup/how-to/download-bcm-packages.md)
- [How to extract `cmsh` without installing it](docs/cmsh_setup/how-to/extract-cmsh-without-installing.md)
- [How to make `cmsh` permanent and convenient](docs/cmsh_setup/how-to/make-cmsh-permanent.md)
- [How to set up `cmsh` credentials](docs/cmsh_setup/how-to/set-up-cmsh-credentials.md)
- [How to troubleshoot a `cmsh` connection](docs/cmsh_setup/how-to/troubleshoot-connection.md)
- [Explanation: why `dpkg -x` instead of `apt install`](docs/cmsh_setup/explanation/why-dpkg-x.md)
- [Explanation: version parity and upgrade risk](docs/cmsh_setup/explanation/version-parity.md)
- [Explanation: how `cmsh` talks to CMDaemon](docs/cmsh_setup/explanation/how-cmsh-talks-to-cmdaemon.md)
- [Reference: environment as built](docs/cmsh_setup/reference/environment.md)
- [Reference: commands used](docs/cmsh_setup/reference/commands.md)

#### Compute-node SSH access

- [Overview](docs/compute_node_ssh_access/README.md)
- [How to install the Slurm SSH gate on one live compute node](docs/compute_node_ssh_access/how-to/install-ssh-gate-on-one-compute-node.md)
- [How to install the Slurm SSH gate on the compute-node fleet](docs/compute_node_ssh_access/how-to/install-ssh-gate-on-the-compute-node-fleet.md)
- [How to verify the Slurm SSH gate](docs/compute_node_ssh_access/how-to/verify-slurm-ssh-gate.md)
- [Explanation: how the SSH access policy works](docs/compute_node_ssh_access/explanation/how-the-ssh-access-policy-works.md)

#### Observability server setup

- [Overview: Slurm client-only node](docs/observability_server_setup/README.md)
- [Tutorial: make a standalone host into a Slurm client](docs/observability_server_setup/tutorial.md)
- [Explanations](docs/observability_server_setup/explanation.md)
- [Reference](docs/observability_server_setup/reference.md)
- [How to add the `cmods` user to another node](docs/observability_server_setup/how-to/add-cmods-user.md)
- [How to align local UIDs with the cluster](docs/observability_server_setup/how-to/align-uids.md)
- [How to configure Enroot for NGC and Pyxis jobs](docs/observability_server_setup/how-to/configure-enroot.md)
- [How to set up SSH access to managed nodes](docs/observability_server_setup/how-to/distribute-ssh-keys.md)
- [How to make `srun` and `sbatch` work](docs/observability_server_setup/how-to/enable-job-submission.md)
- [How to install Enroot for container job submission](docs/observability_server_setup/how-to/install-enroot.md)
- [How to install Slurm client binaries without BCM repository access](docs/observability_server_setup/how-to/install-slurm-binaries.md)
- [How to set up the shared filesystems](docs/observability_server_setup/how-to/mount-cm-shared.md)
- [How to make the Slurm client work permanently](docs/observability_server_setup/how-to/persist-environment.md)
- [How to run commands across Slurm node groups with `clush`](docs/observability_server_setup/how-to/set-up-clush.md)
- [How to resolve cluster hostnames through the BCM head node](docs/observability_server_setup/how-to/set-up-dns.md)
- [How to set up munge with the cluster's key](docs/observability_server_setup/how-to/set-up-munge.md)
- [How to troubleshoot a failing `sinfo` or `squeue`](docs/observability_server_setup/how-to/troubleshoot.md)
- [Explanation: how a client-only Slurm node works](docs/observability_server_setup/explanation/client-only-slurm-node.md)
- [Explanation: why `clush` groups come from Slurm](docs/observability_server_setup/explanation/clustershell-groups.md)
- [Explanation: why cluster DNS uses systemd-resolved](docs/observability_server_setup/explanation/dns-design.md)
- [Explanation: Munge, UIDs, and non-interactive environments](docs/observability_server_setup/explanation/identity-and-environment.md)
- [Explanation: why submission needs more than query tools](docs/observability_server_setup/explanation/submission-dependencies.md)

## Cluster helper

[`scripts/check_node_busy.sh`](scripts/check_node_busy.sh) is a PAM helper that
succeeds only when the local node has no Slurm-managed processes.
