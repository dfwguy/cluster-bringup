# Cluster Bringup

Guides and scripts for setting up, accessing, and operating NVIS OVA infrastructure.
Choose a guide below, then use its tutorial for a first setup, how-to guides for
specific tasks, reference for configuration values, and explanations for design
and operational tradeoffs.

- [Omnistation GitLab group credentials](omnistation_gitlab_credentials/README.md) — use an NVIS GitLab group token with Varlock, Git, and Codex on an Omnistation.
- [App server performance tuning](app_server_tuning/README.md) — tune the storage and write path of an app server, or find out why its RAID5 writes are slow.
- [Cluster identity and automation access](cluster_identity_access/README.md) — give a person passwordless cluster access or run controlled automation as `cmods`.
- [Internal web-app access](internal_app_access/README.md) — protect an internal HTTP application with personal client certificates.
- [`cmsh` setup](cmsh_setup/README.md) — run the Bright Cluster Manager shell from a host that BCM does not manage.
- [Compute-node SSH access](compute_node_ssh_access/README.md) — control direct SSH access to compute nodes.
- [Observability server setup](observability_server_setup/README.md) — query, fan out to, or submit work to a BCM-managed Slurm cluster from a standalone host.
- [Tailscale access](tailscale_access/README.md) — reach a jumpbox through an overlapping private network.

The [complete documentation index](README.md) lists every guide page.
The [repository overview](../README.md) introduces the available scripts.
