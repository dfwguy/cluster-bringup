# Documentation index

This index links every document in this directory.

## Cluster identity and automation access

- [Overview](cluster_identity_access/README.md)
- [Tutorial: provision a person for passwordless cluster access](cluster_identity_access/tutorial.md)
- [How to operate as `cmods`](cluster_identity_access/how-to/operate-as-service-account.md)
- [Explanation: why identities are separate](cluster_identity_access/explanation/identity-boundaries.md)
- [Reference: cluster access model](cluster_identity_access/reference/access-model.md)

## `cmsh` setup

- [Overview: running `cmsh` from a non-BCM host](cmsh_setup/README.md)
- [Tutorial: connect `cmsh` from a non-BCM host](cmsh_setup/tutorial.md)
- [How to download BCM packages for an offline install](cmsh_setup/how-to/download-bcm-packages.md)
- [How to extract `cmsh` without installing it](cmsh_setup/how-to/extract-cmsh-without-installing.md)
- [How to make `cmsh` permanent and convenient](cmsh_setup/how-to/make-cmsh-permanent.md)
- [How to set up `cmsh` credentials](cmsh_setup/how-to/set-up-cmsh-credentials.md)
- [How to troubleshoot a `cmsh` connection](cmsh_setup/how-to/troubleshoot-connection.md)
- [Explanation: why `dpkg -x` instead of `apt install`](cmsh_setup/explanation/why-dpkg-x.md)
- [Explanation: version parity and upgrade risk](cmsh_setup/explanation/version-parity.md)
- [Explanation: how `cmsh` talks to CMDaemon](cmsh_setup/explanation/how-cmsh-talks-to-cmdaemon.md)
- [Reference: environment as built](cmsh_setup/reference/environment.md)
- [Reference: commands used](cmsh_setup/reference/commands.md)

## Compute-node SSH access

- [Overview](compute_node_ssh_access/README.md)
- [How to install the Slurm SSH gate on one live compute node](compute_node_ssh_access/how-to/install-ssh-gate-on-one-compute-node.md)
- [How to install the Slurm SSH gate on the compute-node fleet](compute_node_ssh_access/how-to/install-ssh-gate-on-the-compute-node-fleet.md)
- [How to verify the Slurm SSH gate](compute_node_ssh_access/how-to/verify-slurm-ssh-gate.md)
- [Explanation: how the SSH access policy works](compute_node_ssh_access/explanation/how-the-ssh-access-policy-works.md)

## Observability server setup

- [Overview: Slurm client-only node](observability_server_setup/README.md)
- [Tutorial: make a standalone host into a Slurm client](observability_server_setup/tutorial.md)
- [Explanations](observability_server_setup/explanation.md)
- [Reference](observability_server_setup/reference.md)
- [How to add the `cmods` user to another node](observability_server_setup/how-to/add-cmods-user.md)
- [How to align local UIDs with the cluster](observability_server_setup/how-to/align-uids.md)
- [How to configure Enroot for NGC and Pyxis jobs](observability_server_setup/how-to/configure-enroot.md)
- [How to set up SSH access to managed nodes](observability_server_setup/how-to/distribute-ssh-keys.md)
- [How to make `srun` and `sbatch` work](observability_server_setup/how-to/enable-job-submission.md)
- [How to install Enroot for container job submission](observability_server_setup/how-to/install-enroot.md)
- [How to install Slurm client binaries without BCM repository access](observability_server_setup/how-to/install-slurm-binaries.md)
- [How to set up the shared filesystems](observability_server_setup/how-to/mount-cm-shared.md)
- [How to make the Slurm client work permanently](observability_server_setup/how-to/persist-environment.md)
- [How to run commands across Slurm node groups with `clush`](observability_server_setup/how-to/set-up-clush.md)
- [How to resolve cluster hostnames through the BCM head node](observability_server_setup/how-to/set-up-dns.md)
- [How to set up munge with the cluster's key](observability_server_setup/how-to/set-up-munge.md)
- [How to troubleshoot a failing `sinfo` or `squeue`](observability_server_setup/how-to/troubleshoot.md)
- [Explanation: how a client-only Slurm node works](observability_server_setup/explanation/client-only-slurm-node.md)
- [Explanation: why `clush` groups come from Slurm](observability_server_setup/explanation/clustershell-groups.md)
- [Explanation: why cluster DNS uses systemd-resolved](observability_server_setup/explanation/dns-design.md)
- [Explanation: Munge, UIDs, and non-interactive environments](observability_server_setup/explanation/identity-and-environment.md)
- [Explanation: why submission needs more than query tools](observability_server_setup/explanation/submission-dependencies.md)
