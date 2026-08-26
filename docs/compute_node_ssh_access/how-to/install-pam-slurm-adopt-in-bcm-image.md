# How to install `pam_slurm_adopt` in a BCM software image

Use this procedure to install the module in a compute-node image. It does not
enable the PAM policy; use the test and policy how-tos afterward.

## 1. Check the repository candidates

This cluster's daemon is Slurm 25.05. Confirm the BCM package family on the
head node, then inspect its PAM package in the intended image:

```console
dpkg -l | grep -E '^ii[[:space:]]+slurm25\.05'
cm-chroot-sw-img /cm/images/<compute-image>
apt-cache policy slurm25.05-pam
exit
```

Use BCM's `slurm25.05-pam` package. Do not substitute Ubuntu's
`libpam-slurm-adopt`; its 23.11 release does not match this cluster.

## 2. Install the matching packages

Install the BCM PAM package and set `SLURM_CONF` for the Ubuntu SSH service in
the image:

```console
cm-chroot-sw-img /cm/images/<compute-image>
apt-get install slurm25.05-pam
sed -i '\|^SLURM_CONF=|d' /etc/default/ssh
printf '%s\n' 'SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf' \
  >> /etc/default/ssh
dpkg-query -W -f='${Package} ${Version}\n' slurm25.05-pam
find /lib /usr/lib -type f -name pam_slurm_adopt.so -print
exit
```

Do not add PAM rules in the image at this stage. The `SLURM_CONF` line is
inherited by the SSH PAM process after the service restarts.

## 3. Send the updated image to one node

Choose a drained test node. `imageupdate` without `-w` is a dry run; review
the sync log before the write operation:

```console
cmsh -c 'device; imageupdate -n <test-node>'
cmsh -c 'device; synclog -n <test-node>'
cmsh -c 'device; imageupdate -n <test-node> -w'
```

Continue with [test `pam_slurm_adopt` on one compute node](test-pam-slurm-adopt-on-a-compute-node.md).
