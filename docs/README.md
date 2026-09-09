# Documentation index

This index links every document in this directory.

## Choose a guide

| If you need to… | Start here | Why use it |
|---|---|---|
| Use an NVIS GitLab group token with Varlock, Git, and Codex on an Omnistation | [Omnistation GitLab group credentials](omnistation_gitlab_credentials/README.md) | Builds a device-local credential workspace, verifies API and repository access, and keeps child Git history separate. |
| Tune the storage and write path of an app server, or find out why its RAID5 writes are slow | [App server performance tuning](app_server_tuning/README.md) | Gives the method, the measurement traps, and a table of every value that must be re-derived per host. |
| Give a person passwordless cluster access or run controlled automation as `cmods` | [Cluster identity and automation access](cluster_identity_access/README.md) | Establishes the separate human and service identities, SSH keys, and least-privilege access boundaries. |
| Protect an internal HTTP application with personal client certificates | [Internal web-app access](internal_app_access/README.md) | Deploys Caddy mTLS at each site with centralized client-certificate issuance and revocation guidance. |
| Run the Bright Cluster Manager shell from a host that BCM does not manage | [`cmsh` setup](cmsh_setup/README.md) | Connects an external host to CMDaemon without installing the full BCM stack. |
| Control direct SSH access to compute nodes | [Compute-node SSH access](compute_node_ssh_access/README.md) | Enforces Slurm job-aware admission while retaining a safe fallback for idle nodes. |
| Query, fan out to, or submit work to a BCM-managed Slurm cluster from a standalone host | [Observability server setup](observability_server_setup/README.md) | Sets up a client-only Slurm environment, including munge, DNS, `clush`, and optional job submission. |
| Reach a jumpbox through an overlapping private network | [Tailscale access](tailscale_access/README.md) | Adds a narrowly scoped host-route workaround and explains when identical site networks need a different design. |

## App server performance tuning

| Document | Use it for |
|---|---|
| [Overview](app_server_tuning/README.md) | Understanding the scope of the tuning and what transfers to another host. |
| [Tutorial: see the tuning work](app_server_tuning/tutorials/see-the-tuning-work.md) | Reading an array's live settings and watching the parity threads, read-only, on a live host. |
| [How to apply the md tuning](app_server_tuning/how-to/apply-md-tuning.md) | Setting the RAID5 tunables, persisting them, and confirming they took. |
| [How to benchmark the array](app_server_tuning/how-to/benchmark-cluster.md) | Establishing a baseline or verifying a change, and knowing which numbers are comparable. |
| [How to compare md settings](app_server_tuning/how-to/compare-md-settings.md) | Sweeping tunable combinations and measuring run-to-run variance. |
| [How to measure the parity path's CPU](app_server_tuning/how-to/measure-parity-cpu.md) | Finding out whether RAID5 parity is the current bottleneck. |
| [How to enable TRIM on a RAID5 array](app_server_tuning/how-to/enable-trim.md) | Turning on discard without a reboot, and the BCM change that makes it persist. |
| [Reference: values to re-derive on a new host](app_server_tuning/reference/values-to-re-derive.md) | Porting the tuning to a different app server without copying the wrong numbers. |
| [Reference: the array and its tunables](app_server_tuning/reference/md0.md) | Looking up array geometry, each tunable, and what silently resets it. |
| [Reference: hardware](app_server_tuning/reference/hardware.md) | Looking up CPU/NUMA layout, memory, drives, PCIe link widths, and the bond. |
| [Reference: measurements](app_server_tuning/reference/results.md) | Comparing your results against the recorded eight-configuration sweep. |
| [Explanation: why writes were slow](app_server_tuning/explanation/md-write-throughput.md) | Understanding which tunable mattered, and how an unmeasured inherited value survived review. |
| [Explanation: the parity coordinator](app_server_tuning/explanation/the-parity-coordinator.md) | Understanding why a thread at 100% does not mean throughput is capped. |
| [Explanation: why the tuning vanished](app_server_tuning/explanation/tunables-that-do-not-persist.md) | Understanding why sysfs tunables are lost on re-assembly with no symptom. |
| [Explanation: discard on RAID5](app_server_tuning/explanation/discard-on-raid5.md) | Understanding why RAID5 refuses TRIM by default and when it is safe to assert otherwise. |
| [Explanation: PXE boot and local config](app_server_tuning/explanation/pxe-boot-and-local-config.md) | Working out which local changes on a network-booted host actually persist. |
| [Explanation: the Gen4 ceiling](app_server_tuning/explanation/the-gen4-ceiling.md) | Recognising a structural interconnect limit rather than a tuning target. |
| [Explanation: how the benchmarks lied](app_server_tuning/explanation/benchmarking-this-array.md) | Avoiding four measurement errors that each produced a confident wrong answer. |

## Omnistation GitLab group credentials

| Document | Use it for |
|---|---|
| [Overview](omnistation_gitlab_credentials/README.md) | Choosing the first-time, rotation, verification, troubleshooting, or existing-repository path. |
| [Tutorial: use a Varlock GitLab group token](omnistation_gitlab_credentials/tutorial.md) | Creating the credential workspace, verifying token and project permissions, and launching Codex in a new or existing group-project clone. |
| [How to rotate an NVIS GitLab group token](omnistation_gitlab_credentials/how-to/rotate-group-token.md) | Replacing an expiring, revoked, or superseded token without losing the previous encrypted value before validation. |
| [How to verify GitLab API and repository access](omnistation_gitlab_credentials/how-to/verify-gitlab-access.md) | Checking token state, all four scopes, group role, repository reads, and dry-run feature-branch writes. |
| [How to troubleshoot Varlock-backed GitLab access](omnistation_gitlab_credentials/how-to/troubleshoot-gitlab-access.md) | Separating authentication, authorization, network, credential-helper, and working-directory failures. |
| [How to launch Codex for an existing group repository](omnistation_gitlab_credentials/how-to/launch-codex-for-existing-repository.md) | Using the reusable owner-only launcher to start or resume Codex in any permitted group repository. |
| [Reference: Varlock-backed NVIS GitLab credentials](omnistation_gitlab_credentials/reference/varlock-gitlab-reference.md) | Looking up variables, decorators, scopes, access levels, paths, permissions, commands, and HTTP meanings. |
| [Explanation: credential workspace and runtime trust](omnistation_gitlab_credentials/explanation/credential-workspace-and-runtime-trust.md) | Understanding repository ownership, encrypted-at-rest versus runtime access, askpass, YOLO isolation, and the preview credential proxy. |

## Tailscale access

| Document | Use it for |
|---|---|
| [Overview](tailscale_access/README.md) | Choosing a safe approach to a Tailscale subnet that overlaps another network. |
| [How to reach one jumpbox through an overlapping subnet](tailscale_access/how-to/reach-one-jumpbox.md) | Installing, testing, and maintaining a narrow client-side `/32` route. |
| [Explanation: why a host route helps—and when it cannot](tailscale_access/explanation/overlapping-private-networks.md) | Understanding route selection and why identical site networks need unique destinations. |

## Cluster identity and automation access

| Document | Use it for |
|---|---|
| [Overview](cluster_identity_access/README.md) | Choosing the identity and access path that fits a person or automation task. |
| [Tutorial: provision a person for passwordless cluster access](cluster_identity_access/tutorial.md) | Creating an individual cluster identity and installing its SSH key. |
| [How to operate as `cmods`](cluster_identity_access/how-to/operate-as-service-account.md) | Running approved automation under the service account without sharing a personal identity. |
| [Explanation: why identities are separate](cluster_identity_access/explanation/identity-boundaries.md) | Understanding the security boundaries between personal users and `cmods`. |
| [Reference: cluster access model](cluster_identity_access/reference/access-model.md) | Looking up the roles, authentication methods, and access constraints in the cluster model. |

## Internal web-app access

| Document | Use it for |
|---|---|
| [Overview](internal_app_access/README.md) | Choosing the guide for Caddy, an HTTP upstream, mTLS, and certificate revocation. |
| [Tutorial: deploy one Caddy-protected HTTP service](internal_app_access/tutorial.md) | Creating the first protected application path, using Gunicorn as an example. |
| [How to add a Caddy-protected site](internal_app_access/how-to/add-caddy-site.md) | Adding another application site. |
| [How to enroll a client certificate](internal_app_access/how-to/install-client-certificate.md) | Using the approved client enrollment mechanism to submit a device-generated CSR. |
| [How to revoke a client certificate](internal_app_access/how-to/revoke-client-certificate.md) | Removing access after offboarding or compromise. |
| [Reference: Caddy mTLS application access](internal_app_access/reference/configuration.md) | Looking up paths, configuration, CRL sync, and acceptance criteria. |
| [Explanation: architecture and trust boundaries](internal_app_access/explanation/architecture-and-trust.md) | Understanding separate server/client TLS trust and revocation behavior. |
| [Explanation: rejected connection and enrollment methods](internal_app_access/explanation/rejected-methods.md) | Understanding why application DNS/direct access and signing-server PFX delivery are excluded. |

## `cmsh` setup

| Document | Use it for |
|---|---|
| [Overview: running `cmsh` from a non-BCM host](cmsh_setup/README.md) | Assessing the prerequisites and workflow for an external `cmsh` client. |
| [Tutorial: connect `cmsh` from a non-BCM host](cmsh_setup/tutorial.md) | Completing the end-to-end first connection to CMDaemon. |
| [How to download BCM packages for an offline install](cmsh_setup/how-to/download-bcm-packages.md) | Collecting the required packages when the client host cannot reach BCM repositories. |
| [How to extract `cmsh` without installing it](cmsh_setup/how-to/extract-cmsh-without-installing.md) | Using the `cmsh` binary without changing the host's package installation. |
| [How to make `cmsh` permanent and convenient](cmsh_setup/how-to/make-cmsh-permanent.md) | Persisting the client setup for routine administrative use. |
| [How to set up `cmsh` credentials](cmsh_setup/how-to/set-up-cmsh-credentials.md) | Installing and configuring the X.509 credentials required by CMDaemon. |
| [How to troubleshoot a `cmsh` connection](cmsh_setup/how-to/troubleshoot-connection.md) | Diagnosing authentication, network, or version failures. |
| [Explanation: why `dpkg -x` instead of `apt install`](cmsh_setup/explanation/why-dpkg-x.md) | Understanding why the client is unpacked instead of installed through APT. |
| [Explanation: version parity and upgrade risk](cmsh_setup/explanation/version-parity.md) | Deciding how closely the client must track the cluster's BCM version. |
| [Explanation: how `cmsh` talks to CMDaemon](cmsh_setup/explanation/how-cmsh-talks-to-cmdaemon.md) | Understanding the protocol and trust relationship behind the client connection. |
| [Reference: environment as built](cmsh_setup/reference/environment.md) | Comparing a host's environment with the known working configuration. |
| [Reference: commands used](cmsh_setup/reference/commands.md) | Finding the commands used throughout the `cmsh` setup. |

## Compute-node SSH access

| Document | Use it for |
|---|---|
| [Overview](compute_node_ssh_access/README.md) | Understanding the job-aware SSH policy and selecting the appropriate deployment path. |
| [How to install the Slurm SSH gate on one live compute node](compute_node_ssh_access/how-to/install-ssh-gate-on-one-compute-node.md) | Piloting or repairing the gate on a single running node. |
| [How to install the Slurm SSH gate on the compute-node fleet](compute_node_ssh_access/how-to/install-ssh-gate-on-the-compute-node-fleet.md) | Rolling the gate into the BCM software image for all compute nodes. |
| [How to verify the Slurm SSH gate](compute_node_ssh_access/how-to/verify-slurm-ssh-gate.md) | Confirming that the policy permits and denies SSH access as intended. |
| [Explanation: how the SSH access policy works](compute_node_ssh_access/explanation/how-the-ssh-access-policy-works.md) | Understanding PAM, `pam_slurm_adopt`, and the idle-node fallback. |

## Observability server setup

| Document | Use it for |
|---|---|
| [Overview: Slurm client-only node](observability_server_setup/README.md) | Understanding the scope and prerequisites of a standalone Slurm client host. |
| [Tutorial: make a standalone host into a Slurm client](observability_server_setup/tutorial.md) | Building the baseline client configuration from start to finish. |
| [Explanations](observability_server_setup/explanation.md) | Navigating the conceptual material for the client-only design. |
| [Reference](observability_server_setup/reference.md) | Looking up the configuration values and commands used by the guide. |
| [How to add the `cmods` user to another node](observability_server_setup/how-to/add-cmods-user.md) | Provisioning the service account on an additional client host. |
| [How to align local UIDs with the cluster](observability_server_setup/how-to/align-uids.md) | Matching local identities to cluster UIDs so Slurm and munge agree. |
| [How to configure Enroot for NGC and Pyxis jobs](observability_server_setup/how-to/configure-enroot.md) | Enabling NGC authentication and Pyxis-compatible container execution. |
| [How to set up SSH access to managed nodes](observability_server_setup/how-to/distribute-ssh-keys.md) | Distributing SSH keys for administrative access from the client host. |
| [How to make `srun` and `sbatch` work](observability_server_setup/how-to/enable-job-submission.md) | Adding the dependencies needed to submit, rather than only inspect, jobs. |
| [How to install Enroot for container job submission](observability_server_setup/how-to/install-enroot.md) | Installing the container runtime used for Enroot/Pyxis submissions. |
| [How to install Slurm client binaries without BCM repository access](observability_server_setup/how-to/install-slurm-binaries.md) | Obtaining Slurm commands on a host outside BCM package management. |
| [How to set up the shared filesystems](observability_server_setup/how-to/mount-cm-shared.md) | Mounting cluster-shared paths needed by users and jobs. |
| [How to make the Slurm client work permanently](observability_server_setup/how-to/persist-environment.md) | Persisting environment changes across shells and reboots. |
| [How to run commands across Slurm node groups with `clush`](observability_server_setup/how-to/set-up-clush.md) | Managing or inspecting Slurm node groups through ClusterShell. |
| [How to resolve cluster hostnames through the BCM head node](observability_server_setup/how-to/set-up-dns.md) | Configuring name resolution for cluster hosts. |
| [How to set up munge with the cluster's key](observability_server_setup/how-to/set-up-munge.md) | Establishing the authentication shared secret required by Slurm. |
| [How to troubleshoot a failing `sinfo` or `squeue`](observability_server_setup/how-to/troubleshoot.md) | Diagnosing failed Slurm query commands. |
| [Explanation: how a client-only Slurm node works](observability_server_setup/explanation/client-only-slurm-node.md) | Understanding which services a query-only client needs and why. |
| [Explanation: why `clush` groups come from Slurm](observability_server_setup/explanation/clustershell-groups.md) | Understanding how ClusterShell group membership is sourced. |
| [Explanation: why cluster DNS uses systemd-resolved](observability_server_setup/explanation/dns-design.md) | Understanding the resolver design and its cluster-DNS routing. |
| [Explanation: Munge, UIDs, and non-interactive environments](observability_server_setup/explanation/identity-and-environment.md) | Understanding identity consistency and environment pitfalls. |
| [Explanation: why submission needs more than query tools](observability_server_setup/explanation/submission-dependencies.md) | Understanding the extra components required for `srun` and `sbatch`. |
