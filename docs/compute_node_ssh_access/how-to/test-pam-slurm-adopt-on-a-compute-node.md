# How to test `pam_slurm_adopt` on one compute node

Use a drained test node after its BCM image has the matching Slurm PAM module.
Keep a root session open throughout. This verifies adoption only; it does not
install the idle-node helper or the final access policy.

## 1. Verify the installed package and Slurm prerequisites

```console
sudo find /lib /usr/lib -type f -name pam_slurm_adopt.so -print
pam_adopt=$(find /lib /usr/lib -type f -name pam_slurm_adopt.so -print -quit)
ldd "$pam_adopt" | grep libslurm
dpkg-query -W -f='${Package} ${Version}\n' slurm25.05-pam
sudo env -i \
  PATH=/cm/local/apps/slurm/current/bin:/usr/bin:/bin \
  SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf \
  /cm/local/apps/slurm/current/bin/scontrol show config | \
  grep -Ei '^(PrologFlags|TaskPlugin|ProctrackType)'
```

The module, library, and plugins must match Slurm 25.05. Require
`PrologFlags=contain`, `TaskPlugin=task/cgroup`, and
`ProctrackType=proctrack/cgroup` before testing. Jobs started before
`PrologFlags=contain` do not have an external step and cannot be adopted.
If the site also needs `PrologFlags=Alloc`, retain it and add `contain` (for
example, `PrologFlags=Alloc,contain`); `Alloc` alone is not the adoption
requirement.

Disable `pam_systemd.so` in PAM files included by `sshd`:

```console
sudo grep -RniE '^[[:space:]]*[^#].*pam_systemd\.so' /etc/pam.d
```

## 2. Verify `slurm.conf` is visible to SSH PAM

```console
sudo env -i \
  PATH=/cm/local/apps/slurm/current/bin:/usr/bin:/bin \
  SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf \
  /cm/local/apps/slurm/current/bin/scontrol show config >/dev/null \
  && echo 'shared Slurm configuration works'

sudo grep -x 'SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf' \
  /etc/default/ssh
sudo sshd -t
sudo systemctl restart ssh.service
sudo systemctl show ssh.service -p Environment -p EnvironmentFiles
```

The final command must show the shared configuration path and `/etc/default/ssh`.

## 3. Add one temporary account rule

After the normal account includes in `/etc/pam.d/sshd`, add only:

```pam
account [success=done ignore=ignore default=die] pam_slurm_adopt.so action_no_jobs=ignore action_adopt_failure=deny action_generic_failure=deny
```

Do not add a `session ... pam_slurm_adopt.so` line or a `conf=` option.

## 4. Prove adoption

Start a new Slurm job after the containment settings are active. SSH to the
node as that job's owner. In the new shell:

```console
echo "job=$SLURM_JOB_ID shell=$$"
cat /proc/$$/cgroup
```

The shell must be in that job's `step_extern` cgroup. A successful login alone
does not prove adoption.

In a root terminal, collect logs while reproducing the login:

```console
sudo journalctl -f -o short-iso | grep --line-buffered -Ei \
  'sshd|pam_slurm_adopt|slurmd'
```

Do not proceed if logs show `PluginDir`, DNS-SRV, or adoption failures. Remove
the temporary PAM rule after testing fails, or continue to the [SSH policy
how-to](gate-ssh-access-on-slurm-activity.md) only after adoption succeeds.
