# App server performance tuning

Tuning the storage and write path of a cluster app server: what it taught us on
`appserver-nc` (Nscale NC), 2026-08-21 to 2026-08-27, written up so the method
transfers to the next one.

Organised by what you are doing, following [Diátaxis](https://diataxis.fr/).
Four directories, four different jobs:

| If you are… | Go to |
|---|---|
| new to this host and want to see the tuning for yourself | [tutorials/](#tutorials) |
| trying to get something specific done | [how-to/](#how-to-guides) |
| looking up a value, a device, or a measured number | [reference/](#reference) |
| trying to understand why it is set this way | [explanation/](#explanation) |

## Scope — read this before copying a value

This is a **worked case study of one host**, not a portable settings file. Every
number here was measured on a single Dell PowerEdge R760 with six NVMe drives in
a RAID5 behind XFS, ~1 TiB of RAM, PXE-booted from BCM, serving `/cluster` over
NFS. The reasoning generalises; the values do not.

The central finding is precisely about the danger of copying: `group_thread_cnt`
was inherited from another cluster's bundle with a plausible written rationale,
and was wrong by 49% on this hardware — see
[md-write-throughput.md](explanation/md-write-throughput.md). Doing that again
with the numbers on this page would be repeating the mistake this documentation
exists to record.

So, on a new app server: read [explanation/](#explanation) for the method, then
work through [values-to-re-derive.md](reference/values-to-re-derive.md), which
lists every value that is site-specific and how to obtain it for your host.

The case-study host is named throughout, deliberately, so it is always clear
whose measurement you are reading. Identifiers that would be actively wrong if
copied — the array UUID, the home server address — are placeholders instead, with
the command to read your own alongside them.

The sysctl, systemd, `/etc/exports` and `nfsmount.conf` half of the tuning is a
separate artifact (the `appserver-tuning` bundle, of which
`/usr/local/sbin/appserver-tuning.sh` is the part these pages touch) and is not
included in this repo.

Command examples are written relative to a checkout root holding a `tools/`
directory, so `bash tools/mdcpu.sh` assumes you are standing in it. See
[Tools](#tools) for where those scripts currently live.

## What changed, in one table

For anyone who only reads one thing. Each row links to why.

| Finding | Effect |
|---|---|
| `group_thread_cnt` was 4 by inheritance, never measured here. It is the single largest lever on write throughput | Sequential writes **+49%** at 8 threads. See [md-write-throughput.md](explanation/md-write-throughput.md) |
| `stripe_cache_size` is nearly irrelevant on its own, despite being the value everyone reaches for | +18% alone, against +489% for threads. Same page |
| Stopping and re-assembling the array silently reverts every md tunable to kernel defaults | Cost 74-81% of write throughput for a day, undetected. See [tunables-that-do-not-persist.md](explanation/tunables-that-do-not-persist.md) |
| TRIM was never enabled, because `raid456` defaults to refusing discard | ~34.9 TiB never reclaimed. See [discard-on-raid5.md](explanation/discard-on-raid5.md) |
| This host PXE-boots kernel and initramfs from BCM, so locally rebuilt initrds and `modprobe.d` are inert | The TRIM fix must go through BCM, not this host. See [pxe-boot-and-local-config.md](explanation/pxe-boot-and-local-config.md) |
| The NVMe drives are Gen5, the R760 U.2 bays are Gen4 **by design** | Reads were already at 92% of the achievable ceiling. Nothing to fix. See [the-gen4-ceiling.md](explanation/the-gen4-ceiling.md) |
| One kernel thread, `md0_raid5`, coordinates all parity and saturates at ~96% no matter how many workers exist | Sets a hard ceiling on small random writes. See [the-parity-coordinator.md](explanation/the-parity-coordinator.md) |
| Several of our own early measurements were wrong in ways that looked convincing | See [benchmarking-this-array.md](explanation/benchmarking-this-array.md) before trusting any number |

Net result on `/cluster`: sequential writes went from about 1.4 GiB/s to about
8.3 GiB/s, roughly **5.5x**, with p99 write latency down about **80%**. Reads did
not move at all, and could not have — see the Gen4 page.

## Tutorials

Learning-oriented. One guided path, no options. Read this when you have *no*
problem, to build the model the how-to guides assume.

| Page | Covers |
|------|--------|
| [see-the-tuning-work.md](tutorials/see-the-tuning-work.md) | Read the array's live settings, watch the parity threads while a write runs, and find the same numbers in the saved results. Read-only throughout |

## How-to guides

Task-oriented, for someone who already knows the host.

| Page | Covers |
|------|--------|
| [apply-md-tuning.md](how-to/apply-md-tuning.md) | Set the tunables now, make them survive a reboot, and confirm they did |
| [benchmark-cluster.md](how-to/benchmark-cluster.md) | `bench-cluster.sh` — what it runs, what it costs, which numbers are comparable |
| [compare-md-settings.md](how-to/compare-md-settings.md) | `tune-md.sh` — sweep configurations, repeat runs to measure variance, read the matrix |
| [measure-parity-cpu.md](how-to/measure-parity-cpu.md) | `mdcpu.sh` — find out whether the parity path is the bottleneck right now |
| [enable-trim.md](how-to/enable-trim.md) | Turn discard on without a reboot, and the BCM change that makes it stick |

## Reference

Lookup-oriented. Dry, complete, scannable.

| Page | Covers |
|------|--------|
| [values-to-re-derive.md](reference/values-to-re-derive.md) | **Start here on a new host.** Every site-specific value, and how to obtain it for yours |
| [md0.md](reference/md0.md) | Array geometry, every tunable, its value, where it is set and what sets it back |
| [hardware.md](reference/hardware.md) | CPU and NUMA layout, memory, the six NVMe drives, PCIe link widths, the bond |
| [results.md](reference/results.md) | Every measurement from the eight-configuration sweep of 2026-08-27 |

## Explanation

Understanding-oriented. Why it is like this, and what it cost to find out.

| Page | Covers |
|------|--------|
| [md-write-throughput.md](explanation/md-write-throughput.md) | Why writes were slow, why threads are the lever and cache is not, and how an unmeasured default survived review |
| [the-parity-coordinator.md](explanation/the-parity-coordinator.md) | The one thread that cannot be parallelised, why 96% busy is not the same as capped, and why we stopped at 8 |
| [tunables-that-do-not-persist.md](explanation/tunables-that-do-not-persist.md) | Why sysfs settings vanish on re-assembly, why nothing warned us, and the shape of a fix that cannot silently fail |
| [discard-on-raid5.md](explanation/discard-on-raid5.md) | Why RAID5 refuses discard by default, why it is safe on these drives, and what TRIM did and did not buy |
| [pxe-boot-and-local-config.md](explanation/pxe-boot-and-local-config.md) | Which local changes on this host persist and which are theatre |
| [the-gen4-ceiling.md](explanation/the-gen4-ceiling.md) | Gen5 drives in Gen4 bays, how we got this wrong twice, and why it is a procurement finding |
| [benchmarking-this-array.md](explanation/benchmarking-this-array.md) | Four ways our own benchmarks lied, and how each was caught |

## Tools

Four scripts back the how-to guides and the tutorial. **They are not in this
repo yet** — they live on the case-study host under the tuning checkout's
`tools/` directory, and the command examples assume you have them in a local
`tools/`. None of them are installed anywhere; run them from the checkout. All
four are read-only except where noted.

| Script | Does | Documented in |
|---|---|---|
| `bench-cluster.sh` | `fio` suite against `/cluster`. **Writes** 64 GiB to `/cluster/bench` | [benchmark-cluster.md](how-to/benchmark-cluster.md) |
| `tune-md.sh` | Applies tunable combinations, benchmarks each, restores on exit. **Writes** | [compare-md-settings.md](how-to/compare-md-settings.md) |
| `mdcpu.sh` | Per-thread CPU for the parity path. Read-only, no `sudo` | [measure-parity-cpu.md](how-to/measure-parity-cpu.md) |
| `enable-trim.sh` | Enables discard without a reboot. **Takes `/cluster` briefly offline** | [enable-trim.md](how-to/enable-trim.md) |

`fio` and `jq` are required by the first two: `sudo apt install fio jq`.

An earlier `tune-md-sweep.sh` is deliberately not included — `tune-md.sh`
supersedes it, and its restore logic reinstated whatever it found rather than the
intended values, which is how this host spent a day de-tuned.

## Adding to this

A new page goes in exactly one of the four directories. The split that gets
misjudged most often is reference against explanation: the tunable table is
reference, *why that value* is explanation. A page that needs to be both is two
pages.
