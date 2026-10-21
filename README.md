# nvis-ova-scripts

Scripts and documentation for NVIS OVA infrastructure.

## Docs

Start at the [documentation home](docs/index.md) or browse the
[complete documentation index](docs/README.md).

The client guides cover giving a standalone (non-BCM-managed) Ubuntu host
access to a BCM cluster. The compute-node guide covers SSH access policy on
the managed cluster itself. The app server guide covers tuning such a host once
it is running, rather than connecting it.

| Guide | Gives you | Talks to |
|---|---|---|
| [docs/omnistation_gitlab_credentials/](docs/omnistation_gitlab_credentials/) | A Varlock-protected NVIS GitLab group token and reusable Git/Codex access across permitted group repositories | Varlock, GitLab API, Git over HTTPS, and Codex |
| [docs/observability_server_setup/](docs/observability_server_setup/) | `sinfo`, `squeue`, `sacct` — a read-only Slurm client, plus `clush` fan-out | Slurm controller, TCP 6817, munge + matching UID |
| [docs/cmsh_setup/](docs/cmsh_setup/) | `cmsh` — the interactive BCM management shell | CMDaemon, TCP 8081, X.509 client certificate |
| [docs/compute_node_ssh_access/](docs/compute_node_ssh_access/) | Job-aware SSH admission on compute nodes, with an idle-node fallback | Local PAM stack, `pam_slurm_adopt`, and `scontrol` |
| [docs/cluster_identity_access/](docs/cluster_identity_access/) | Individual, passwordless cluster identities and service-account operations | BCM, SSH public keys, `cmods`, and controlled `sudo` |
| [docs/tailscale_access/](docs/tailscale_access/) | Reach a distinct jumpbox when private subnets overlap | Tailscale subnet routing and a client-side `/32` host route |
| [docs/app_server_tuning/](docs/app_server_tuning/) | A method for tuning an app server's RAID5/NFS write path, plus the values to re-derive per host | `md` sysfs tunables, XFS alignment, `fio`, and a BCM kernel parameter |

## Cluster helper

[`scripts/check_node_busy.sh`](scripts/check_node_busy.sh) is a PAM helper that
succeeds only when the local node has no Slurm-managed processes.
