# Apply the md0 tuning

For when the array is running at the wrong values — after a manual re-assembly,
after a disk replacement, or when a check says so. Values and what resets them are
in [md0.md](../reference/md0.md).

## Check first

```bash
echo "gtc=$(cat /sys/block/md0/md/group_thread_cnt) \
scs=$(cat /sys/block/md0/md/stripe_cache_size) \
ra=$(cat /sys/block/md0/queue/read_ahead_kb)"
```

Expected: `gtc=8 scs=16384 ra=2048`.

`gtc=0 scs=256` means the array is at kernel defaults — someone stopped and
re-assembled it, and sequential writes are running about 5x slow. Nothing else
will indicate this: the array reads at full speed, mounts, exports and reports
`[UUUUUU]` clean.

## Apply now

```bash
echo 16384 | sudo tee /sys/block/md0/md/stripe_cache_size
echo 8     | sudo tee /sys/block/md0/md/group_thread_cnt
echo 2048  | sudo tee /sys/block/md0/queue/read_ahead_kb
```

Set the cache before the threads. Workers start looking for stripe buffers as soon
as they exist, so growing the cache first avoids a brief window where more workers
contend for the default 256 buffers.

Takes effect immediately, no remount, no client disruption. Re-run the check above
to confirm — the kernel silently clamps out-of-range values rather than failing, so
reading back is the only proof.

Equivalently, re-run the whole boot-time script:

```bash
sudo /usr/local/sbin/appserver-tuning.sh
```

It is idempotent and covers the network and sysctl settings too. Prefer it if you
do not know what else may have drifted.

## Make it survive a reboot

Persistence is `/usr/local/sbin/appserver-tuning.sh`, run at boot by
`appserver-tuning.service`. Change the value there:

```bash
sudo cp -a /usr/local/sbin/appserver-tuning.sh \
           /usr/local/sbin/appserver-tuning.sh.bak-$(date +%F)
sudo sed -i 's/^GROUP_THREADS=4$/GROUP_THREADS=8/' /usr/local/sbin/appserver-tuning.sh
grep -n '^STRIPE_CACHE=\|^GROUP_THREADS=\|^READ_AHEAD=' /usr/local/sbin/appserver-tuning.sh
```

Expected:

```
STRIPE_CACHE=16384
GROUP_THREADS=8
READ_AHEAD=2048
```

Keep the bundle's own `files/appserver-tuning.sh` in step with the installed
copy, or the next install silently reverts it.

Do **not** add a separate systemd unit for these values. One existed as a draft
and was deleted: it hardcoded the same two numbers, giving two places for them to
disagree. `appserver-tuning.sh` is the single source of truth.

## After anything stops the array

Re-assembly discards all three values. `enable-trim.sh` handles this itself — it
snapshots them during preflight and re-applies them after re-assembly, before the
mount. Anything else does not:

```bash
sudo mdadm --stop /dev/md0
sudo mdadm --assemble /dev/md0 ...
# tunables are now at kernel defaults; re-apply them
```

So after any manual array surgery, run the check, then the apply block, then the
check again. If you are writing a script that stops the array, copy the
snapshot-and-re-apply pattern out of `enable-trim.sh` rather than hardcoding
values.

## Verify after a reboot

```bash
systemctl status appserver-tuning.service
echo "gtc=$(cat /sys/block/md0/md/group_thread_cnt) scs=$(cat /sys/block/md0/md/stripe_cache_size)"
cat /sys/block/md0/queue/discard_max_bytes
```

The md tunables should be correct, because the service ran. `discard_max_bytes`
will be **0**, because TRIM is not persistent on this host and reverts on every
boot — that is expected until the BCM change lands. See
[enable-trim.md](enable-trim.md).

## If a value will not stick

Check the ceiling. `stripe_cache_size` maxes at 32768 on this kernel and a larger
request is clamped, not rejected. `group_thread_cnt` accepts up to 8192.

Check you are on the right array. The script discovers RAID5 arrays by walking
`/sys/block/md*/md`, and `mdadm` does not guarantee `md0` across a BCM reimage. If
the array came back as `md127`, the paths above are wrong but the script is right:

```bash
grep ^md /proc/mdstat
```
