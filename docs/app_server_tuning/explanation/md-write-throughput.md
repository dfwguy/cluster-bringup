# Why writes were slow

`/cluster` is XFS on `md0`, a six-drive RAID5 of Micron 9550 PRO NVMe. When we
first measured it, sequential writes ran at about 1.4 GiB/s against reads of
40.3 GiB/s — a 28:1 asymmetry on hardware where the drives themselves are
symmetric. Tuning closed most of that gap, to about 8.3 GiB/s. This page is about
which knob did it, which knob didn't, and why we spent a week believing the wrong
one mattered.

## RAID5 makes writes structurally expensive

Every write to a RAID5 stripe has to update parity, and parity is computed over
the whole stripe. Here the chunk is 64 KiB across six members, five of which hold
data in any given stripe, so a full stripe is 320 KiB.

A write that covers a complete stripe is cheap in principle: the kernel has all
five data chunks in hand, XORs them, and issues six writes. A write that covers
part of a stripe cannot do that. It must first *read* the chunks it is not
overwriting, or read the old data and old parity, before it can compute the new
parity. That is the read-modify-write penalty, and it turns one logical write into
two reads and two writes.

This is why the write path needs CPU at all, and it is the entire reason the two
tunables below exist. Reads have no equivalent cost: a RAID5 read is a lookup and
a forward, with no parity involvement whatsoever. That asymmetry explains why
every result in this document shows reads completely unmoved by tuning.

## The two knobs, and which one matters

`/sys/block/md0/md/stripe_cache_size` is how many stripe head buffers the array
keeps. The kernel default is 256, which on a six-member array is about 6 MB. If
the cache is too small, stripes get evicted before neighbouring writes arrive to
complete them, so writes that *could* have been assembled into full stripes
degrade into read-modify-write instead.

`/sys/block/md0/md/group_thread_cnt` is how many worker threads process stripes.
The kernel default is 0, which does not mean "no threads" — it means all parity
work runs on the single `md0_raid5` kernel thread.

Both were expected to matter. Only one did:

| Change | Sequential write, 1280K aligned |
|---|---|
| kernel defaults: `gtc=0, scs=256` | 1447 MiB/s |
| cache alone: `gtc=0, scs=8192` | 1707 MiB/s (+18%) |
| threads alone: `gtc=2, scs=8192` | 5372 MiB/s (+271%) |
| both, tuned: `gtc=8, scs=16384` | 7741 MiB/s (+435%) |

Raising the cache 32-fold while leaving the thread count alone bought 18%, and on
several other tests in the same column it was *negative*. Adding two threads
bought 271%. The full matrix is in [results.md](../reference/results.md).

The reason is that the cache and the threads are not two independent
optimisations. A larger cache lets more stripes be in flight, but something has to
process them, and with `gtc=0` that something is one CPU core doing XOR for six
NVMe drives. Growing the queue in front of a single-server queue does not increase
throughput; it just makes the queue longer. Once workers exist to drain it, the
cache stops being the constraint — which is also why `scs=8192` versus `16384`
trades wins test by test at `gtc=8` and is not worth arguing about.

We kept 16384 anyway, not on benchmark evidence but because 384 MB against 1 TiB
of RAM is free, and every measurement here was taken with eight local `fio` jobs
rather than many NFS clients writing concurrently. The cache is the resource that
concurrency pressure consumes first, so paying nothing for headroom is reasonable
even though we cannot demonstrate a benefit.

## How the wrong value survived review

`GROUP_THREADS=4` was not chosen for this host. It came from the TX 16k bundle,
and the adaptation README recorded the decision honestly — this is the row as it
read before this work, since corrected:

| Value | Source | appserver-nc | Note |
|---|---|---|---|
| `GROUP_THREADS` | 4 | 4 | Same core count and array width |

"Same core count and array width" is a real argument. It is also not a
measurement, and it was wrong by 49% on this workload. Nobody was careless: the
value was inherited from a bundle that worked, with a stated rationale, on
genuinely comparable hardware.

What made it stick was that the failure was invisible. A de-tuned RAID5 array
serves reads at full speed, mounts normally, exports normally, and reports
`[UUUUUU] clean`. There is no log line, no counter, no alert. The only symptom is
a number nobody had measured, because the host was new and idle and there was
nothing to compare against.

The generalisable lesson is narrow and worth stating plainly: **a value carried
across from another cluster with a plausible rationale is a hypothesis, not a
setting.** It costs one benchmark to find out, and on this host that one benchmark
was worth 49% of write throughput. The tuning bundle's other transferred values —
`dirty_bytes`, `min_free_kbytes`, `fs.file-max`, `RING` — are all still unverified
here by exactly the same standard.

## What we settled on, and what is still open

`group_thread_cnt=8`, `stripe_cache_size=16384`, `read_ahead_kb=2048`.

Eight rather than sixteen is argued in
[the-parity-coordinator.md](the-parity-coordinator.md); the short version is that
sixteen won two tests by a lot, lost two others, and its numbers were internally
inconsistent in a way that means they should not be trusted. That question is not
closed, only parked, and
[compare-md-settings.md](../how-to/compare-md-settings.md) describes the repeated
run that would settle it.

`read_ahead_kb=2048` is the one value on this page still chosen without evidence
from this host. It cannot affect any measurement here, because every `fio` job
used `--direct=1`, which bypasses readahead entirely. It matters only on the
buffered path — which is to say, on everything that actually reaches `/cluster`
over NFS. Nothing in this document justifies 2048 over the 640 the kernel derived
from the stripe geometry, and it should be revisited once real client traffic
exists to measure.
