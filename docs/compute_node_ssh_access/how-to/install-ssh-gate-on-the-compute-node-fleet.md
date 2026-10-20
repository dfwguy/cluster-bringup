# How to install the Slurm SSH gate on the compute-node fleet

Use this only after the complete one-node installation has passed the shared
[verification procedure](verify-slurm-ssh-gate.md). It promotes the exact
tested setup through the BCM image rather than making node-local changes.

## 1. Put every tested artifact in the image

Install the same BCM package and SSH environment proven on the live canary:

```console
cm-chroot-sw-img /cm/images/default-image
dpkg -S /usr/lib/security/pam_slurm_adopt.so 2>/dev/null || true
apt-get -s remove libpam-slurm-adopt
```

If the simulation lists only the old Ubuntu `libpam-slurm-adopt` package,
remove it before installing the BCM package. Both packages own
`/lib/security/pam_slurm_adopt.so`, so installing `slurm25.05-pam` first will
fail with an overwrite error:

```console
apt-get remove libpam-slurm-adopt
```

Then install the BCM package and configure the SSH environment:

```console
apt-get install slurm25.05-pam
sed -i '\|^SLURM_CONF=|d' /etc/default/ssh
printf '%s\n' 'SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf' \
  >> /etc/default/ssh
exit
```

Then ensure all three tested artifacts are present in
`/cm/images/default-image`:

- The BCM package `slurm25.05-pam`.
- `/etc/default/ssh` contains:

  ```text
  SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf
  ```

- `/usr/local/sbin/check_node_busy.sh` is root-owned and mode `0755`.

Open [`check_node_busy.sh`](../../../scripts/check_node_busy.sh) in the
repository and copy its complete contents. While still in the image chroot,
paste it into the helper file and set its permissions:

```console
# In cm-chroot-sw-img /cm/images/default-image
vi /usr/local/sbin/check_node_busy.sh
# Paste the complete linked script, then save and exit vi.
chown root:root /usr/local/sbin/check_node_busy.sh
chmod 0755 /usr/local/sbin/check_node_busy.sh
```

Add the same three account rules proven on the test node to the image's
`/etc/pam.d/sshd` through the site's managed SSH-PAM generation mechanism.
That file identifies its generated section; do not make an unmanaged edit that
the next image/configuration generation will erase.

```text
account [success=done ignore=ignore default=die] pam_slurm_adopt.so action_no_jobs=ignore action_adopt_failure=deny action_generic_failure=deny
account requisite pam_exec.so quiet /usr/local/sbin/check_node_busy.sh
account required  pam_access.so
```

## 2. Update the compute-node group in a controlled rollout

Run a dry run and inspect its log before applying the update. The one-node
procedure is the required small-batch test; use the fleet group only after it
passes verification:

```console
cmsh -c 'device; imageupdate -g computenode'
cmsh -c 'device; synclog'
cmsh -c 'device; imageupdate -g computenode -w'
```

Substitute the actual compute-node group if it is not named `computenode`. Do
not include login or management nodes.

## 3. Verify each rollout batch

Run [verify the Slurm SSH gate](verify-slurm-ssh-gate.md) on a representative
idle node and a node with a local job before considering the rollout complete.
