# How to install `pam_slurm_adopt` in a BCM software image

Use this procedure to install the module in a compute-node image. It does not
enable the PAM policy; use the test and policy how-tos afterward.

## 1. Check the repository candidates

This cluster's daemon is Slurm 25.05. Record its release, then inspect the
repositories enabled inside the intended BCM image:

```console
/cm/local/apps/slurm/current/bin/scontrol --version
cm-chroot-sw-img /cm/images/<compute-image>
apt-cache policy libpam-slurm-adopt libslurm40t64 slurm-wlm-basic-plugins
exit
```

Use packages only when the PAM module, its `libslurm` dependency, and the
plugin package match the daemon's 25.05 release. The Ubuntu Noble candidate
`23.11.4-1.2ubuntu5` does not match this cluster and must not be installed.

## 2. Install the matching packages

When the BCM repository provides matching candidates, install both the module
and its plugins into the image:

```console
cm-chroot-sw-img /cm/images/<compute-image>
apt-get install libpam-slurm-adopt slurm-wlm-basic-plugins
dpkg-query -W -f='${Package} ${Version}\n' \
  libpam-slurm-adopt libslurm40t64 slurm-wlm-basic-plugins
find /lib /usr/lib -type f -name pam_slurm_adopt.so -print
dpkg -L slurm-wlm-basic-plugins | grep -E '/(task_cgroup|proctrack_cgroup)\.so$'
exit
```

Do not add PAM rules in the image at this stage.

## 3. Send the updated image to one node

Choose a drained test node. `imageupdate` without `-w` is a dry run; review
the sync log before the write operation:

```console
cmsh -c 'device; imageupdate -n <test-node>'
cmsh -c 'device; synclog -n <test-node>'
cmsh -c 'device; imageupdate -n <test-node> -w'
```

Continue with [test `pam_slurm_adopt` on one compute node](test-pam-slurm-adopt-on-a-compute-node.md).

## 4. If no matching BCM package exists

Do not mix Ubuntu 23.11 packages with the site's Slurm 25.05 stack. Build only
the PAM contribution from the already-configured source tree that produced the
site daemon:

```console
cd <slurm-25.05-build>/contribs/pam_slurm_adopt
make
sudo make install DESTDIR=/cm/images/<compute-image>
```

The 25.05 build must use `--with-pam_dir` for the target image's PAM module
directory. Determine it from the target image rather than guessing it:

```console
pam_dir=$(dirname "$(readlink -f "$(find /lib /usr/lib -type f -name pam_unix.so -print -quit)")")
printf '%s\n' "$pam_dir"
```

Verify the resulting module under `/cm/images/<compute-image>` with `find`,
update one node, and then continue with the test how-to.
