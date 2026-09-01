# Enable TRIM on `/cluster`

Discard is disabled by default on RAID5. This turns it on without a reboot, and
covers the BCM change needed to make it persist.

Why it is off and why it is safe here:
[discard-on-raid5.md](../explanation/discard-on-raid5.md).

## Is it on?

```bash
cat /sys/block/md0/queue/discard_max_bytes
```

`0` means off, and `fstrim` will silently do nothing while reporting success.
Non-zero — currently `2199023255040` — means on.

```bash
cat /sys/module/raid456/parameters/devices_handle_discard_safely   # Y or N
```

This reverts to `N` on **every reboot**. Check it after any reboot.

## Turn it on now

The module parameter only takes effect when `raid456` binds an array, so the array
must be stopped and re-assembled. `enable-trim.sh` does that safely:

```bash
sudo bash tools/enable-trim.sh
```

It briefly takes `/cluster` offline. In order it: refuses to run on a degraded or
resyncing array; reads the six members live from `/proc/mdstat`; names any process
holding the mount; warns about connected NFSv4 clients; prompts for confirmation;
stops the bring-up timer, unexports, unmounts, sets the parameter, stops and
re-assembles the array, **re-applies the md tunables**, remounts, re-exports, and
restarts the timer.

It rolls back on any failure, restoring service in preference to completing the
change.

Two details worth knowing. Members are read at runtime, never hardcoded, because
NVMe device names are not stable across reboots on this host — on 2026-08-26
`nvme2n1` and `nvme5n1` exchanged serial numbers over a single reboot. And the
array UUID is recorded in the script header for manual recovery:

```bash
# Read the UUID first -- it is per-array, so the one in the script header is not
# yours: mdadm --detail /dev/md0 | awk '/UUID/{print $3}'
mdadm --assemble /dev/md0 --uuid=<array-uuid> --scan
```

### Then reclaim the space

```bash
nvme list                          # note Usage per drive
bash tools/bench-cluster.sh -c
sudo fstrim -v /cluster            # needs root: FITRIM is CAP_SYS_ADMIN
nvme list                          # Usage should drop sharply
```

`fstrim` without `sudo` fails with `FITRIM ioctl failed: Operation not permitted`.

On first run this reclaimed about 34.9 TiB and took a while. Watching `nvme list`
usage fall is the only direct confirmation that discards reached the drives.

### Check nothing was left behind

The script restores services itself, but the failure mode that bit us was `nfsd`
not coming back:

```bash
mountpoint /cluster
systemctl is-active nfs-server
exportfs -s
echo "gtc=$(cat /sys/block/md0/md/group_thread_cnt) scs=$(cat /sys/block/md0/md/stripe_cache_size)"
```

If `nfs-server` is inactive: `sudo systemctl restart nfs-server`.

## Make it persist — the BCM change

This cannot be fixed from this host. The parameter must be set as `raid456` loads,
and this host PXE-boots its kernel and initramfs from BCM, so a locally rebuilt
initramfs and a local `modprobe.d` drop-in both appear to work and both do nothing.
See [pxe-boot-and-local-config.md](../explanation/pxe-boot-and-local-config.md).

Hand this to AIC. Add to the kernel command line for this host's boot
configuration:

```
raid456.devices_handle_discard_safely=Y
```

In `cmsh`, on the category or node this host boots from:

```
device use appserver-nc
set kernelparameters "raid456.devices_handle_discard_safely=Y"
commit
```

Append to any existing parameters rather than replacing them — read the current
value first.

Supporting argument for the change request: the drives are Micron 9550 PRO
reporting `dlfeat: 9`, meaning deallocated blocks read back as zeros
deterministically. That is exactly the guarantee RAID5 parity needs, and
`devices_handle_discard_safely=Y` is the kernel's intended mechanism for asserting
it. This is not a workaround.

**Status: open.** Until it lands, every reboot silently disables discard, and
re-enabling it means another `enable-trim.sh` run with another brief `/cluster`
outage.

## Routine trimming

Once persistent, the normal mechanism is fine:

```bash
systemctl enable --now fstrim.timer     # weekly
```

Do not enable this while `discard_max_bytes` is 0 — it will run weekly and do
nothing, which is worse than not having it because it looks like coverage.
