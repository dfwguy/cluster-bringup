# How to install the Slurm SSH gate on one compute node

Use a drained compute node as the rollout test. This installs the complete
setup—BCM Slurm PAM package, SSH environment, helper, and PAM rules—on that
node only. Keep an existing root session open until verification succeeds.

## 1. Install the BCM package in the image and update one node

Confirm that the head node has the matching BCM Slurm package family, then add
the PAM package and Slurm configuration environment to the node image:

```console
dpkg -l | grep -E '^ii[[:space:]]+slurm25\.05'
cm-chroot-sw-img /cm/images/default-image
apt-get install slurm25.05-pam
sed -i '\|^SLURM_CONF=|d' /etc/default/ssh
printf '%s\n' 'SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf' \
  >> /etc/default/ssh
exit
```

Send the changed image to the single drained node. Review the dry-run sync log
before adding `-w`:

```console
cmsh -c 'device; imageupdate -n <test-node>'
cmsh -c 'device; synclog -n <test-node>'
cmsh -c 'device; imageupdate -n <test-node> -w'
```

## 2. Install the helper on the test node

From the repository checkout, copy the helper and install the copied file:

```console
scp scripts/check_node_busy.sh <admin-user>@<test-node>:check_node_busy.sh
ssh <admin-user>@<test-node> \
  'sudo install -o root -g root -m 0755 check_node_busy.sh /usr/local/sbin/check_node_busy.sh'
```

## 3. Configure the SSH PAM account stack

On the test node, verify the image supplied `SLURM_CONF`, then restart SSH:

```console
sudo grep -x 'SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf' /etc/default/ssh
sudo sshd -t
sudo systemctl daemon-reload
sudo systemctl restart ssh.service
sudo systemctl show ssh.service -p Environment -p EnvironmentFiles
```

After the normal account includes in `/etc/pam.d/sshd`, add:

```pam
account [success=done ignore=ignore default=die] pam_slurm_adopt.so action_no_jobs=ignore action_adopt_failure=deny action_generic_failure=deny
account requisite pam_exec.so quiet /usr/local/sbin/check_node_busy.sh
account required  pam_access.so
```

Do not add a `session ... pam_slurm_adopt.so` line or `conf=` option. The
service environment supplies `SLURM_CONF` to the module.

## 4. Verify before promoting

Follow [verify the Slurm SSH gate](verify-slurm-ssh-gate.md). Do not install it
on additional nodes until all adoption, busy-node, and idle-node checks pass.
