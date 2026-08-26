# How to gate SSH access on Slurm activity

Use this procedure to allow `root` and users with a local Slurm job to connect
to a compute node. Other users can connect only when the node is idle and
`/etc/security/access.conf` allows them.

## Prerequisites

- Install the PAM adoption module directly from APT whenever modifying the
  image **or** testing on a compute node that can reach its configured APT
  mirror:

  ```console
  sudo apt install libpam-slurm-adopt
  ```

  Use the `/cluster/tmp/` staging procedure only when the running compute node
  cannot reach its APT mirror. The artifacts must match the target node's
  architecture;
  for example, do **not** install packages downloaded as `amd64` on an `arm64`
  compute node.

  On the offline target, record the required architecture and package versions:

  ```console
  dpkg --print-architecture
  apt-cache policy libslurm40t64 libpam-slurm-adopt
  ```

  Choose the staging command that matches the target value from
  `dpkg --print-architecture`.

  For an `amd64` target, use the networked x86 Ubuntu Noble staging host's
  normal APT configuration:

  ```console
  stage=/cluster/tmp/pam-slurm-adopt/amd64
  mkdir -p "$stage"
  cd "$stage"
  apt-get download \
    libslurm40t64=23.11.4-1.2ubuntu5 \
    libpam-slurm-adopt=23.11.4-1.2ubuntu5
  dpkg-deb -f ./*.deb Package Version Architecture
  sha256sum *.deb > SHA256SUMS
  ```

  Confirm that both `dpkg-deb` rows end in `amd64`.

  For an `arm64` target, use the following on a networked Ubuntu Noble host.
  It uses an isolated ARM64 APT list, so it does not alter the staging host's
  configured package sources or native architecture:

  ```console
  stage=/cluster/tmp/pam-slurm-adopt/arm64
  mkdir -p "$stage/lists/partial"
  cat > "$stage/ports-arm64.list" <<'EOF'
  deb [arch=arm64 signed-by=/usr/share/keyrings/ubuntu-archive-keyring.gpg] http://ports.ubuntu.com/ubuntu-ports noble universe
  EOF
  apt-get \
    -o Dir::Etc::sourcelist="$stage/ports-arm64.list" \
    -o Dir::Etc::sourceparts=- \
    -o Dir::State::lists="$stage/lists" \
    -o APT::Architecture=arm64 update
  cd "$stage"
  apt-get \
    -o Dir::Etc::sourcelist="$stage/ports-arm64.list" \
    -o Dir::Etc::sourceparts=- \
    -o Dir::State::lists="$stage/lists" \
    -o APT::Architecture=arm64 download \
    libslurm40t64=23.11.4-1.2ubuntu5 \
    libpam-slurm-adopt=23.11.4-1.2ubuntu5
  dpkg-deb -f ./*.deb Package Version Architecture
  sha256sum *.deb > SHA256SUMS
  ```

  Confirm that both `dpkg-deb` rows end in `arm64`. On the offline compute
  node, use the matching staged directory to verify and install the packages:

  ```console
  target_arch=$(dpkg --print-architecture)
  cd "/cluster/tmp/pam-slurm-adopt/$target_arch"
  sha256sum -c SHA256SUMS
  sudo dpkg -i ./libslurm40t64_*.deb ./libpam-slurm-adopt_*.deb
  ```

  `libslurm40t64` is the dependency required by `libpam-slurm-adopt` on Ubuntu
  Noble. If the target's APT policy selects a different version, replace both
  version pins with that target-selected version; do not stage packages from
  another Ubuntu release or architecture.

  Confirm that the package installed `pam_slurm_adopt.so` before editing the
  SSH PAM stack:

  ```console
  sudo find /lib /usr/lib -type f -name pam_slurm_adopt.so 2>/dev/null
  ```

- `pam_slurm_adopt.so` and its Slurm containment requirements are configured.
- SSH uses PAM, and `pam_systemd.so` is disabled in PAM files included by
  `sshd`.
- `/etc/profile.d/modules.sh` is installed, and `module load slurm` provides
  `scontrol`.
- `/etc/security/access.conf` contains the intended idle-node access rules.

## 1. Install the busy-node helper

Install the repository
[`check_node_busy.sh` helper](../../../scripts/check_node_busy.sh):

```console
sudo install -o root -g root -m 0755 scripts/check_node_busy.sh \
    /usr/local/sbin/check_node_busy.sh
```

## 2. Configure the PAM policy

Keep the existing `account` entries in `/etc/pam.d/sshd`. Add these entries
after the normal account includes:

```pam
account [success=done ignore=ignore default=die] pam_slurm_adopt.so action_no_jobs=ignore action_adopt_failure=deny action_generic_failure=deny
account requisite pam_exec.so quiet /usr/local/sbin/check_node_busy.sh
account required  pam_access.so
```

Keep this order and these control flags. Check included PAM files for an earlier
`account sufficient` entry, which could return before this policy runs.

The first rule deliberately bypasses the helper for `root` and for a user whose
SSH session is adopted into that user's local job. `action_no_jobs=ignore`
makes users without a local job continue to the helper, which permits an idle
node and rejects a node with other Slurm job steps.

## 3. Test on one compute node

Keep an existing root session open and test on one drained compute node first.
Run the helper on an idle node:

```console
sudo /usr/local/sbin/check_node_busy.sh
echo $?
```

The result must be `0`. Start a Slurm job on the node, run the helper again, and
confirm that it returns `1`.

The helper intentionally treats this raw Slurm result as an idle node and
returns `0` itself:

```console
/cm/local/apps/slurm/current/bin/scontrol listpids 2>&1
# No job steps exist on this node.
echo $?
# 1
```

Any other `scontrol` error is fail-closed and causes the helper to return `1`.

From a second terminal, test these SSH connections:

| Situation | Expected result |
|---|---|
| `root` | Login succeeds |
| User owns a local job | Login succeeds and is adopted into the job's external step |
| User owns no local job; node has Slurm-managed PIDs | Login fails |
| User owns no local job; node has no Slurm-managed PIDs; `pam_access` allows | Login succeeds |
| User owns no local job; node has no Slurm-managed PIDs; `pam_access` denies | Login fails |

Roll out the PAM change to the remaining compute nodes only after every test
passes.
