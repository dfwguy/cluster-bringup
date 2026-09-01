# Values to re-derive on a new host

Every value in this documentation that is a property of the case-study host
rather than of RAID5, plus how to obtain the equivalent for a different app
server. Neutral lookup table; the arguments live in
[explanation/](../README.md#explanation).

The case-study host is a Dell PowerEdge R760, 2 × Xeon Gold 6430 (64c/128t, 2
NUMA nodes), ~1 TiB RAM, six Micron 9550 PRO NVMe in a RAID5 (`md0`, 64 KiB
chunk) behind XFS at `/cluster`, PXE-booted from BCM, exporting NFSv4.2. Full
detail in [hardware.md](hardware.md) and [md0.md](md0.md).

**Copying a value off this page without re-deriving it is the exact mistake this
documentation records.** `group_thread_cnt` arrived here as an inherited `4` with
a written rationale — "same core count and array width" — and was wrong by 49%
on this workload. See
[md-write-throughput.md](../explanation/md-write-throughput.md).

## The table

| Value | Here | How to re-derive |
|---|---|---|
| Full stripe | **320 KiB** | `chunk × (members − 1)` for RAID5. Read chunk and member count from `/proc/mdstat`. Every alignment argument in these pages is relative to this number, so derive it first |
| `group_thread_cnt` | **8** | **Measure it. Do not transfer it.** Non-zero values are workers *per NUMA node*, so 8 is 16 workers on a two-node host. Sweep with [compare-md-settings.md](../how-to/compare-md-settings.md) and pick the point where no metric has regressed |
| `stripe_cache_size` | **16384** | Cost is `value × 4 KiB × member_count` — 384 MiB here, immaterial against 1 TiB. Scale to available RAM. The kernel ceiling is 32768 and an over-range write is **clamped silently**, so read the value back |
| `read_ahead_kb` | **2048** | Unverified even here, and cannot be settled by these benchmarks: every `fio` job used `--direct=1`, which bypasses readahead. The kernel derives 640 from the array geometry. Only affects the buffered path, which is what NFS clients use |
| `wbt_lat_usec` on member parent disks | **0** | Check the live value before claiming a change — it was 2000 µs on every member here, so disabling it was real. A host already at 0 gains nothing |
| `devices_handle_discard_safely` | **`Y`** | Only assert this if the drives guarantee deterministic zero reads after discard. Precondition below |
| XFS `sunit` / `swidth` | already correct in the superblock | In 512-byte sectors: `sunit` = chunk size, `swidth` = `sunit` × data-disk count. A 64 KiB chunk on 6-disk RAID5 gives `sunit=128,swidth=640`. Compare `xfs_info` against the array before adding an fstab override |
| Sequential read ceiling | **44.0 GiB/s** theoretical, 40.3 measured | Per-drive link bandwidth × drive count. Arithmetic and the Gen5-drives-in-Gen4-bays trap in [the-gen4-ceiling.md](../explanation/the-gen4-ceiling.md) |
| Network egress ceiling | **~46.6 GiB/s** | Bonded line rate. Worth computing alongside the read ceiling: here they are the same order, so the storage ceiling is invisible to NFS clients |
| CPU → NUMA mapping | interleaved, node 0 even / node 1 odd | Read `/sys/devices/system/node/node*/cpulist`. Never derive it arithmetically — assuming contiguous ranges mislabelled every thread in one of our own analyses |
| Persistence mechanism | `appserver-tuning.service` at boot | Depends on whether the host owns its own boot path. Check below |

## Three preconditions to check before applying anything

### Does the host own its kernel command line?

The case-study host PXE-boots its kernel and initramfs from BCM, so anything
consumed *before* the root filesystem mounts — kernel parameters, load-time
module parameters, initramfs hooks, GRUB config — comes from BCM and cannot be
set locally. `update-initramfs` succeeds and is inert.

This is why TRIM is not persistent here and needs a BCM change, while the md
tunables are fine in a local systemd unit. On a host that boots from its own
disk, both are local changes. Determine which kind of host you have before
choosing a persistence mechanism, or you will ship a change that appears to work
and silently reverts on the next reboot.
[pxe-boot-and-local-config.md](../explanation/pxe-boot-and-local-config.md).

### Do the drives support discard safely?

`raid456.devices_handle_discard_safely=Y` is an assertion the administrator makes
on the drives' behalf, and RAID5 parity depends on it being true:

```bash
nvme id-ns /dev/nvme0n1 | grep dlfeat
```

The low three bits of `dlfeat` must be `001` — "deallocated blocks read as all
zeros". Anything else and the array can hold silently corrupt redundancy, which
surfaces during a rebuild. Reasoning in
[discard-on-raid5.md](../explanation/discard-on-raid5.md).

### Are the array's device names stable?

They were not here — two drives exchanged serial numbers across a single reboot.
Anything that needs the member list must read it from `/proc/mdstat` at runtime,
find the array by UUID, and mount by filesystem UUID. Hardcoding `nvme2n1p1` or
even `md0` is unsafe; `mdadm` does not guarantee the array name across a reimage.

## Before trusting your own numbers

The measurement traps cost more time on this host than the tuning did, and none
of them are specific to it. Read
[benchmarking-this-array.md](../explanation/benchmarking-this-array.md) before
quoting a result, and at minimum:

- Report the ordering you expect *before* looking. Stripe-aligned writes must
  beat unaligned ones; if they do not, that run is noise, not a discovery.
- Sample parity-path CPU during a **write**. RAID5 reads never enter it, so a
  read workload returns a correct and completely uninformative 0%.
- Keep the dataset-allocating first write out of the comparison set. It pays XFS
  extent allocation; every later test overwrites.
- Treat single-sample comparisons as unresolved when the margin is smaller than
  the largest unexplained inconsistency in the same dataset.

## Values deliberately not tuned here

Recorded so they are not mistaken for oversights. The wider tuning bundle also
carries `vm.dirty_bytes`, `vm.min_free_kbytes`, `fs.file-max`, NIC ring sizes and
the CPU governor; those were transferred from another cluster and, by the same
standard this documentation applies to `group_thread_cnt`, remain **unverified**
on this hardware. Nothing in these pages measures them.
