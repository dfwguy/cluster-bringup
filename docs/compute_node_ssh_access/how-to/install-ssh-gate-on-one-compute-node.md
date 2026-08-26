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

## 2. Install and configure the live node

From the repository checkout, copy the helper to the test node:

```console
scp scripts/check_node_busy.sh <admin-user>@<test-node>:check_node_busy.sh
```

Then, on the live test node, install the matching BCM PAM package, set the
Slurm configuration environment for SSH, and install that copied helper:

```console
sudo apt-get install slurm25.05-pam
sudo sed -i '\|^SLURM_CONF=|d' /etc/default/ssh
printf '%s\n' 'SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf' \
  | sudo tee -a /etc/default/ssh >/dev/null
sudo install -o root -g root -m 0755 check_node_busy.sh \
  /usr/local/sbin/check_node_busy.sh
```

## 3. Configure the SSH PAM account stack

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

## 4. Verify or roll back

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
