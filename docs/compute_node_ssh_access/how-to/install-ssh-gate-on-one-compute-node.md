# How to install the Slurm SSH gate on one live compute node

Use a drained compute node as a live, reversible canary. Do **not** modify the
BCM software image in this procedure. The fleet procedure is responsible for
putting the validated setup into the image.

Keep an existing root session open throughout. An ordinary reboot reverses
these changes only when the node is reprovisioned from its unmodified image;
otherwise use the rollback commands below.

## 1. Record rollback copies

On the live test node, preserve the files that this procedure changes:

```console
sudo install -d -m 0700 /root/slurm-ssh-gate-backup
sudo cp -a /etc/default/ssh /root/slurm-ssh-gate-backup/ssh
sudo cp -a /etc/pam.d/sshd /root/slurm-ssh-gate-backup/sshd
```

Confirm the BCM package is available on the node:

```console
dpkg -l | grep -E '^ii[[:space:]]+slurm25\.05'
sudo apt-cache policy slurm25.05-pam
```

## 2. Install `pam_slurm_adopt`

Install BCM's Slurm-25.05 PAM module directly on the live test node:

```console
sudo apt-get install slurm25.05-pam
sudo find /lib /usr/lib -type f -name pam_slurm_adopt.so -print
dpkg-query -W -f='${Package} ${Version}\n' slurm25.05-pam
```

The `find` command must print `pam_slurm_adopt.so`. Do not install Ubuntu's
`libpam-slurm-adopt`; it is Slurm 23.11 and does not match this cluster.

### 2.1 Install when the live node has no network access

Use APT on a host that can reach the BCM repository; it reuses that host's
configured BCM repository credentials. Do not use `wget` against the package
URL: the BCM repository returns `401 Unauthorized` without those credentials.
The commands below create an isolated ARM64 package-list state under
`/cluster/tmp/` and do not alter the staging host's normal APT state:

```console
stage=/cluster/tmp/slurm25.05-pam/arm64
mkdir -p "$stage/lists/partial"
rm -f "$stage"/*.deb "$stage/SHA256SUMS"
source_file=$(grep -Rl 'updates-us-east.brightcomputing.com/deb/cm/11.0' \
  /etc/apt/sources.list /etc/apt/sources.list.d 2>/dev/null | head -n 1)
test -n "$source_file"
sed \
  -e 's#/amd64/#/arm64/#g' \
  -e 's/arch=amd64/arch=arm64/g' \
  "$source_file" > "$stage/bcm-arm64.list"
sudo apt-get \
  -o Dir::Etc::sourcelist="$stage/bcm-arm64.list" \
  -o Dir::Etc::sourceparts=- \
  -o Dir::State::lists="$stage/lists" \
  -o APT::Architecture=arm64 update
cd "$stage"
sudo apt-get \
  -o Dir::Etc::sourcelist="$stage/bcm-arm64.list" \
  -o Dir::Etc::sourceparts=- \
  -o Dir::State::lists="$stage/lists" \
  -o APT::Architecture=arm64 download \
  slurm25.05-pam=25.05.8-101099-cm11.0-a3a58b4841
package=slurm25.05-pam_25.05.8-101099-cm11.0-a3a58b4841_arm64.deb
test "$(dpkg-deb -f "$package" Package)" = slurm25.05-pam
test "$(dpkg-deb -f "$package" Version)" = 25.05.8-101099-cm11.0-a3a58b4841
test "$(dpkg-deb -f "$package" Architecture)" = arm64
printf '%s\n' 'OK: authenticated BCM ARM64 package downloaded and verified.'
printf '%s\n' 'The preceding _apt unsandboxed-download warning is expected for this NFS staging directory.'
sha256sum ./*.deb > SHA256SUMS
```

Confirm the `dpkg-deb` output is `slurm25.05-pam`, version
`25.05.8-101099-cm11.0-a3a58b4841`, architecture `arm64`. On the offline
compute node, first check whether an earlier Ubuntu module owns the existing
`.so` file. If it does, simulate its removal and proceed only when the
simulation removes that old package alone:

```console
dpkg -S /usr/lib/security/pam_slurm_adopt.so 2>/dev/null || true
sudo apt-get -s remove libpam-slurm-adopt
```

If `dpkg -S` identifies `libpam-slurm-adopt` and the simulation lists only
that package, remove it:

```console
sudo apt-get remove libpam-slurm-adopt
```

Then verify and install the staged BCM package:

```console
cd /cluster/tmp/slurm25.05-pam/arm64
sha256sum -c SHA256SUMS
sudo dpkg -i ./slurm25.05-pam_25.05.8-101099-cm11.0-a3a58b4841_arm64.deb
sudo find /lib /usr/lib -type f -name pam_slurm_adopt.so -print
dpkg-query -W -f='${Package} ${Version}\n' slurm25.05-pam
```

The APT transaction for this package should list only `slurm25.05-pam`. If
`dpkg -i` reports an unmet dependency, stop and stage the matching BCM
dependency from the same repository; do not use Ubuntu's `libpam-slurm-adopt`
or run `apt-get --fix-broken install` on the offline node.

## 3. Configure SSH and install the helper

Set the Slurm configuration environment for SSH, then install a local copy of
[`check_node_busy.sh`](../../../scripts/check_node_busy.sh). Open that link in
the repository and copy the script to `check_node_busy.sh` in the node's
current directory; it is not under a `scripts/` directory on the node:

```console
sudo sed -i '\|^SLURM_CONF=|d' /etc/default/ssh
printf '%s\n' 'SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf' \
  | sudo tee -a /etc/default/ssh >/dev/null
sudo install -o root -g root -m 0755 ./check_node_busy.sh \
  /usr/local/sbin/check_node_busy.sh
```

## 4. Configure the SSH PAM account stack

After the normal account includes in `/etc/pam.d/sshd`, add:

```pam
account [success=done ignore=ignore default=die] pam_slurm_adopt.so action_no_jobs=ignore action_adopt_failure=deny action_generic_failure=deny
account requisite pam_exec.so quiet /usr/local/sbin/check_node_busy.sh
account required  pam_access.so
```

Do not add a `session ... pam_slurm_adopt.so` line or a `conf=` option. The
`SLURM_CONF` environment from `/etc/default/ssh` is inherited by SSH PAM.

Validate the daemon configuration and restart SSH:

```console
sudo grep -x 'SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf' /etc/default/ssh
sudo sshd -t
sudo systemctl daemon-reload
sudo systemctl restart ssh.service
sudo systemctl show ssh.service -p Environment -p EnvironmentFiles
```

## 5. Verify or roll back

Follow [verify the Slurm SSH gate](verify-slurm-ssh-gate.md). Do not modify the
image or additional nodes until that guide passes completely.

To undo the live canary without reprovisioning, restore the backups, remove
only the test package, and restart SSH:

```console
sudo cp -a /root/slurm-ssh-gate-backup/ssh /etc/default/ssh
sudo cp -a /root/slurm-ssh-gate-backup/sshd /etc/pam.d/sshd
sudo rm -f /usr/local/sbin/check_node_busy.sh
sudo apt-get remove slurm25.05-pam
sudo sshd -t
sudo systemctl daemon-reload
sudo systemctl restart ssh.service
```

Do not run `autoremove` as part of rollback; it could remove unrelated
packages. If the node is reprovisioned from the unmodified image, these live
changes are discarded by that provisioning process.
