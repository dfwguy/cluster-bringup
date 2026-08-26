# How to verify the Slurm SSH gate

Use this after either the one-node installation or each fleet rollout batch.
It verifies package availability, Slurm adoption, and the idle/busy access
policy without changing the configuration.

From the management host, choose the node being verified and connect to it:

```console
managed_host=<managed-compute-node>
ssh $managed_host
# On the Managed Host
```

## 1. Verify the installed dependencies

On the compute node:

```console
sudo find /lib /usr/lib -type f -name pam_slurm_adopt.so -print
dpkg-query -W -f='${Package} ${Version}\n' slurm25.05-pam
sudo grep -x 'SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf' /etc/default/ssh
sudo systemctl show ssh.service -p Environment -p EnvironmentFiles
sudo env -i \
  PATH=/cm/local/apps/slurm/current/bin:/usr/bin:/bin \
  SLURM_CONF=/cm/shared/apps/slurm/etc/slurm/slurm.conf \
  /cm/local/apps/slurm/current/bin/scontrol show config | \
  grep -Ei '^(PrologFlags|TaskPlugin|ProctrackType)'
```

Require `PrologFlags=contain`, `TaskPlugin=task/cgroup`, and
`ProctrackType=proctrack/cgroup`. If the site also uses `PrologFlags=Alloc`,
use `PrologFlags=Alloc,contain`; `Alloc` alone does not create the external
step used for adoption.

`pam_systemd.so` must not appear in PAM files included by `sshd`:

```console
sudo grep -RniE '^[[:space:]]*[^#].*pam_systemd\.so' /etc/pam.d
```

## 2. Verify adoption

Start a new job after containment is configured. SSH to the allocated node as
the job owner. In the new shell, prove that it joined the job's external step:

```console
echo "job=$SLURM_JOB_ID shell=$$"
cat /proc/$$/cgroup
```

The cgroup output must identify the job's `step_extern` cgroup. A successful
login alone does not prove adoption.

## 3. Verify unmanaged idle and busy behavior

On an idle node, the helper must return `0` even though raw `scontrol listpids`
returns `1` with `No job steps exist on this node.`:

```console
sudo /usr/local/sbin/check_node_busy.sh
echo $?
/cm/local/apps/slurm/current/bin/scontrol listpids 2>&1
echo $?
```

Start a job with local processes and confirm the helper returns `1`. Then test
new SSH connections from a second terminal:

| Situation | Expected result |
|---|---|
| root | Login succeeds |
| Owner of a local job | Login succeeds and joins `step_extern` |
| No local job; node has local Slurm processes | Login fails |
| No local job; idle node; `pam_access` allows | Login succeeds |
| No local job; idle node; `pam_access` denies | Login fails |

## 4. Collect failures safely

```console
sudo journalctl -f -o short-iso | grep --line-buffered -Ei \
  'sshd|pam_slurm_adopt|slurmd|pam_exec|check_node_busy'
sudo journalctl -t check_node_busy -n 50 --no-pager
```

Do not promote a node or batch if logs show `PluginDir`, DNS-SRV, adoption, or
unexpected helper failures.
