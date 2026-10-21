Cluster Bringup
===============

Guides and scripts for setting up, accessing, and operating NVIS OVA infrastructure.
Start with a tutorial, use how-to guides for a specific task, consult reference
for configuration values, and read explanations for design and operational tradeoffs.

Choose a guide
--------------

* :doc:`Omnistation GitLab group credentials <docs/omnistation_gitlab_credentials/README>` — Use an NVIS GitLab group token with Varlock, Git, and Codex on an Omnistation
* :doc:`App server performance tuning <docs/app_server_tuning/README>` — Tune the storage and write path of an app server, or find out why its RAID5 writes are slow
* :doc:`Cluster identity and automation access <docs/cluster_identity_access/README>` — Give a person passwordless cluster access or run controlled automation as ``cmods``
* :doc:`Internal web-app access <docs/internal_app_access/README>` — Protect an internal HTTP application with personal client certificates
* :doc:`cmsh setup <docs/cmsh_setup/README>` — Run the Bright Cluster Manager shell from a host that BCM does not manage
* :doc:`Compute-node SSH access <docs/compute_node_ssh_access/README>` — Control direct SSH access to compute nodes
* :doc:`Observability server setup <docs/observability_server_setup/README>` — Query, fan out to, or submit work to a BCM-managed Slurm cluster from a standalone host
* :doc:`Tailscale access <docs/tailscale_access/README>` — Reach a jumpbox through an overlapping private network

Browse the :doc:`complete documentation index <docs/README>` for every page,
or the :doc:`repository overview <README>` for the helper scripts.


.. toctree::
   :maxdepth: 1
   :hidden:
   :caption: Start here

   Home <docs/index>
   Complete documentation index <docs/README>
   Repository overview <README>

.. toctree::
   :maxdepth: 1
   :hidden:
   :caption: GitLab group credentials

   Overview <docs/omnistation_gitlab_credentials/README>
   Tutorial: use a Varlock GitLab group token on an Omnistation <docs/omnistation_gitlab_credentials/tutorial>
   How-to: launch Codex for an existing group repository <docs/omnistation_gitlab_credentials/how-to/launch-codex-for-existing-repository>
   How-to: rotate an NVIS GitLab group token <docs/omnistation_gitlab_credentials/how-to/rotate-group-token>
   How-to: troubleshoot Varlock-backed GitLab access <docs/omnistation_gitlab_credentials/how-to/troubleshoot-gitlab-access>
   How-to: verify GitLab API and repository access <docs/omnistation_gitlab_credentials/how-to/verify-gitlab-access>
   Reference: Varlock-backed NVIS GitLab credentials <docs/omnistation_gitlab_credentials/reference/varlock-gitlab-reference>
   Explanation: credential workspace and runtime trust <docs/omnistation_gitlab_credentials/explanation/credential-workspace-and-runtime-trust>

.. toctree::
   :maxdepth: 1
   :hidden:
   :caption: App server tuning

   Overview <docs/app_server_tuning/README>
   Tutorial: See the tuning work <docs/app_server_tuning/tutorials/see-the-tuning-work>
   How-to: Apply the md0 tuning <docs/app_server_tuning/how-to/apply-md-tuning>
   How-to: Benchmark /cluster <docs/app_server_tuning/how-to/benchmark-cluster>
   How-to: Compare md0 settings <docs/app_server_tuning/how-to/compare-md-settings>
   How-to: Enable TRIM on /cluster <docs/app_server_tuning/how-to/enable-trim>
   How-to: Measure the parity path's CPU <docs/app_server_tuning/how-to/measure-parity-cpu>
   Reference: Hardware <docs/app_server_tuning/reference/hardware>
   Reference: md0 and its tunables <docs/app_server_tuning/reference/md0>
   Reference: Measurements <docs/app_server_tuning/reference/results>
   Reference: Values to re-derive on a new host <docs/app_server_tuning/reference/values-to-re-derive>
   Explanation: Four ways our own benchmarks lied <docs/app_server_tuning/explanation/benchmarking-this-array>
   Explanation: why TRIM was off, and what turning it on bought <docs/app_server_tuning/explanation/discard-on-raid5>
   Explanation: why writes were slow <docs/app_server_tuning/explanation/md-write-throughput>
   Explanation: Which local changes on this host are real <docs/app_server_tuning/explanation/pxe-boot-and-local-config>
   Explanation: Gen5 drives in Gen4 bays <docs/app_server_tuning/explanation/the-gen4-ceiling>
   Explanation: The one thread that cannot be parallelised <docs/app_server_tuning/explanation/the-parity-coordinator>
   Explanation: why the tuning vanished <docs/app_server_tuning/explanation/tunables-that-do-not-persist>

.. toctree::
   :maxdepth: 1
   :hidden:
   :caption: Cluster identity and access

   Overview <docs/cluster_identity_access/README>
   Tutorial: provision a person for passwordless cluster access <docs/cluster_identity_access/tutorial>
   How-to: operate as cmods <docs/cluster_identity_access/how-to/operate-as-service-account>
   Reference: cluster access model <docs/cluster_identity_access/reference/access-model>
   Explanation: why identities are separate <docs/cluster_identity_access/explanation/identity-boundaries>

.. toctree::
   :maxdepth: 1
   :hidden:
   :caption: Internal web-app access

   Overview <docs/internal_app_access/README>
   Tutorial: deploy one Caddy-protected HTTP service <docs/internal_app_access/tutorial>
   How-to: add a Caddy-protected site <docs/internal_app_access/how-to/add-caddy-site>
   How-to: enroll a client certificate <docs/internal_app_access/how-to/install-client-certificate>
   How-to: revoke a client certificate <docs/internal_app_access/how-to/revoke-client-certificate>
   Reference: Caddy mTLS application access <docs/internal_app_access/reference/configuration>
   Explanation: architecture and trust boundaries <docs/internal_app_access/explanation/architecture-and-trust>
   Explanation: rejected connection and enrollment methods <docs/internal_app_access/explanation/rejected-methods>

.. toctree::
   :maxdepth: 1
   :hidden:
   :caption: cmsh setup

   Overview <docs/cmsh_setup/README>
   Tutorial: connect cmsh from a non-BCM host <docs/cmsh_setup/tutorial>
   How-to: download BCM packages for an offline install <docs/cmsh_setup/how-to/download-bcm-packages>
   How-to: extract cmsh without installing it <docs/cmsh_setup/how-to/extract-cmsh-without-installing>
   How-to: make cmsh permanent and convenient <docs/cmsh_setup/how-to/make-cmsh-permanent>
   How-to: set up cmsh credentials <docs/cmsh_setup/how-to/set-up-cmsh-credentials>
   How-to: troubleshoot a cmsh connection <docs/cmsh_setup/how-to/troubleshoot-connection>
   Reference: commands used <docs/cmsh_setup/reference/commands>
   Reference: environment as built <docs/cmsh_setup/reference/environment>
   Explanation: why this works at all: cmsh and CMDaemon <docs/cmsh_setup/explanation/how-cmsh-talks-to-cmdaemon>
   Explanation: Version parity and upgrade risk <docs/cmsh_setup/explanation/version-parity>
   Explanation: why dpkg -x instead of apt install <docs/cmsh_setup/explanation/why-dpkg-x>

.. toctree::
   :maxdepth: 1
   :hidden:
   :caption: Compute-node SSH access

   Overview <docs/compute_node_ssh_access/README>
   How-to: install the Slurm SSH gate on one live compute node <docs/compute_node_ssh_access/how-to/install-ssh-gate-on-one-compute-node>
   How-to: install the Slurm SSH gate on the compute-node fleet <docs/compute_node_ssh_access/how-to/install-ssh-gate-on-the-compute-node-fleet>
   How-to: verify the Slurm SSH gate <docs/compute_node_ssh_access/how-to/verify-slurm-ssh-gate>
   Explanation: how the SSH access policy works <docs/compute_node_ssh_access/explanation/how-the-ssh-access-policy-works>

.. toctree::
   :maxdepth: 1
   :hidden:
   :caption: Observability server setup

   Overview <docs/observability_server_setup/README>
   Tutorial: Make a standalone host into a Slurm client <docs/observability_server_setup/tutorial>
   How-to guides: observability server setup <docs/observability_server_setup/how-to/README>
   How-to: add the cmods user to another node <docs/observability_server_setup/how-to/add-cmods-user>
   How-to: align local UIDs with the cluster <docs/observability_server_setup/how-to/align-uids>
   How-to: configure Enroot for NGC and Pyxis jobs <docs/observability_server_setup/how-to/configure-enroot>
   How-to: set up SSH access to managed nodes <docs/observability_server_setup/how-to/distribute-ssh-keys>
   How-to: make srun and sbatch work <docs/observability_server_setup/how-to/enable-job-submission>
   How-to: install enroot for container job submission <docs/observability_server_setup/how-to/install-enroot>
   How-to: install Slurm client binaries without BCM repository access <docs/observability_server_setup/how-to/install-slurm-binaries>
   How-to: set up the shared filesystems <docs/observability_server_setup/how-to/mount-cm-shared>
   How-to: make the Slurm client work permanently <docs/observability_server_setup/how-to/persist-environment>
   How-to: run commands across Slurm node groups with clush <docs/observability_server_setup/how-to/set-up-clush>
   How-to: resolve cluster hostnames through the BCM head node <docs/observability_server_setup/how-to/set-up-dns>
   How-to: set up munge with the cluster's key <docs/observability_server_setup/how-to/set-up-munge>
   How-to: troubleshoot a failing sinfo or squeue <docs/observability_server_setup/how-to/troubleshoot>
   Reference <docs/observability_server_setup/reference>
   Explanations <docs/observability_server_setup/explanation>
   Explanation: how a client-only Slurm node works <docs/observability_server_setup/explanation/client-only-slurm-node>
   Explanation: why clush groups come from Slurm <docs/observability_server_setup/explanation/clustershell-groups>
   Explanation: why cluster DNS uses systemd-resolved <docs/observability_server_setup/explanation/dns-design>
   Explanation: Munge, UIDs, and non-interactive environments <docs/observability_server_setup/explanation/identity-and-environment>
   Explanation: why submission needs more than query tools <docs/observability_server_setup/explanation/submission-dependencies>

.. toctree::
   :maxdepth: 1
   :hidden:
   :caption: Tailscale access

   Overview <docs/tailscale_access/README>
   How-to: reach one jumpbox through an overlapping subnet <docs/tailscale_access/how-to/reach-one-jumpbox>
   Explanation: why a host route helps—and when it cannot <docs/tailscale_access/explanation/overlapping-private-networks>
