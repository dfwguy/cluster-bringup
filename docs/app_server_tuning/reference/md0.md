# `md0` and its tunables

Facts about the array backing `/cluster`. Neutral: why any value is what it is
belongs in [md-write-throughput.md](../explanation/md-write-throughput.md).

Verified on `appserver-nc`, 2026-08-27.

## Geometry

```
md0 : active raid5 nvme2n1p1[0] nvme6n1p1[6] nvme5n1p1[4] nvme3n1p1[3] nvme1n1p1[2] nvme4n1p1[1]
      37506652160 blocks super 1.2 level 5, 64k chunk, algorithm 2 [6/6] [UUUUUU]
      bitmap: 0/56 pages [0KB], 65536KB chunk
```

| Property | Value |
|---|---|
| Level | RAID5, algorithm 2 (left-symmetric) |
| Members | 6 partitions, one per NVMe drive |
| Chunk | 64 KiB |
| Data members per stripe | 5 (parity distributed across all 6) |
| **Full stripe** | **320 KiB** (5 × 64 KiB) |
| Capacity | 37506652160 KiB = 34.93 TiB |
| Superblock | 1.2 |
| Write-intent bitmap | internal, 65536 KiB chunk, 56 pages |
| Filesystem | XFS, mounted at `/cluster` |
| Array UUID | per-array; read with `mdadm --detail /dev/md0` |

Member device *names* are not stable across reboots. On 2026-08-26, `nvme2n1` and
`nvme5n1` exchanged serial numbers over a single reboot. Anything that needs the
member list must read it from `/proc/mdstat` at runtime; the array itself is found
by UUID, and `/etc/fstab` mounts `/cluster` by filesystem UUID.

320 KiB is the number that matters for write alignment. A write covering a whole
stripe avoids read-modify-write; a partial write does not.

## Tunables

| Path | Value | Kernel default | Set by |
|---|---|---|---|
| `/sys/block/md0/md/group_thread_cnt` | 8 | 0 | `appserver-tuning.sh` at boot |
| `/sys/block/md0/md/stripe_cache_size` | 16384 | 256 | `appserver-tuning.sh` at boot |
| `/sys/block/md0/queue/read_ahead_kb` | 2048 | 640 (derived from geometry) | `appserver-tuning.sh` at boot |
| `/sys/module/raid456/parameters/devices_handle_discard_safely` | `Y` | `N` | **nothing** — set by hand, lost on reboot |

`group_thread_cnt=0` does not mean no threads. It means all parity work runs on
the single `md0_raid5` kernel thread. Any non-zero value is the number of
`raid5wq` workers allocated *per NUMA node*, so `8` produces 16 workers on this
two-node host.

`stripe_cache_size` costs `size × 4 KiB × member_count` of pinned memory: 16384 ×
4 KiB × 6 = 384 MiB. The ceiling on this kernel is 32768; the raise to 262144 is
upstream-only.

Current state:

```bash
cat /sys/block/md0/md/group_thread_cnt      # 8
cat /sys/block/md0/md/stripe_cache_size     # 16384
cat /sys/block/md0/queue/read_ahead_kb      # 2048
cat /sys/block/md0/queue/discard_max_bytes  # 2199023255040 (0 = TRIM off)
```

## What resets them

All three md tunables live in the sysfs directory of an *assembled array
instance*, not of a device. Stopping and re-assembling the array destroys and
recreates that directory with kernel defaults.

| Event | md tunables | `devices_handle_discard_safely` |
|---|---|---|
| Reboot | re-applied by `appserver-tuning.service` | **lost** — reverts to `N` |
| `mdadm --stop` + `--assemble` | **lost** unless re-applied | preserved (module stays loaded) |
| `enable-trim.sh` | snapshotted and re-applied | set to `Y` |
| Any other manual stop/assemble | **lost silently** | preserved |

`appserver-tuning.service` runs at boot only. Nothing re-applies these values at
any other time, and nothing verifies them. See
[tunables-that-do-not-persist.md](../explanation/tunables-that-do-not-persist.md).

`devices_handle_discard_safely` cannot be set persistently from this host at all;
it needs a BCM kernel command line change. See
[pxe-boot-and-local-config.md](../explanation/pxe-boot-and-local-config.md).

## Where the values are declared

`/usr/local/sbin/appserver-tuning.sh`, installed from the tuning bundle's
`files/appserver-tuning.sh`:

```sh
STRIPE_CACHE=16384
GROUP_THREADS=8
READ_AHEAD=2048
```

**Resolved 2026-08-27.** For a few days the bundle declared `GROUP_THREADS=8`
while the installed `/usr/local/sbin/appserver-tuning.sh` still declared `4`, so
a reboot would have silently reverted the array to `group_thread_cnt=4` — about
33% slower on sequential writes. The installed copy is now byte-identical to the
bundle. Re-check after any BCM reimage, which restores the vendor copy:

```bash
diff -q /usr/local/sbin/appserver-tuning.sh files/appserver-tuning.sh
grep -n '^GROUP_THREADS=' /usr/local/sbin/appserver-tuning.sh   # want 8
```

[apply-md-tuning.md](../how-to/apply-md-tuning.md) has the update command.

The script discovers RAID5 arrays by walking `/sys/block/md*/md` and checking
`level`, rather than hardcoding `md0`, because `mdadm` does not guarantee the name
across a BCM reimage.

It also sets `wbt_lat_usec=0` on each member's parent disk, disabling writeback
throttling. That was verified live at 2000 µs on every member before the change,
so it is a real change on this host and not already-default.

## `raid5wq` workqueue

Parity workers run on an unbound workqueue, tunable at
`/sys/devices/virtual/workqueue/raid5wq/`:

| Attribute | Value |
|---|---|
| `affinity_scope` | `cache` (equivalent to `numa` on this CPU) |
| `affinity_strict` | 0 |
| `cpumask` | all CPUs |

Workers are allocated per NUMA node based on the submitting CPU's node, so which
node they land on varies between runs. Not pinned — reasoning in
[the-parity-coordinator.md](../explanation/the-parity-coordinator.md).
