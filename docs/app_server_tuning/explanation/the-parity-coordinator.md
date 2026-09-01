# The one thread that cannot be parallelised

`group_thread_cnt` adds worker threads to the RAID5 write path, and adding them
is worth about 5x on this array. But it does not add threads to all of that path.
One kernel thread, `md0_raid5`, coordinates every stripe on the array, there is
exactly one of it per array, and no tunable changes that.

This page is about what that ceiling does and does not constrain — a distinction
we got wrong first time.

## What the measurement showed

Sampling per-thread CPU during a write, with `gtc=4` (`mdcpu.sh`, see
[measure-parity-cpu.md](../how-to/measure-parity-cpu.md)):

```
md0_raid5                96.6%   CPU 3    node 1     <-- saturated
kworker/u257:0+raid5wq   67.8%   CPU 98   node 0
kworker/u257:6+raid5wq   64.7%   CPU 74   node 0
... 9 more workers, 25-55% each
---
md parity path total: 596% = 5.96 of 128 logical CPUs, across 12 threads
system-wide CPU busy: 1305% of 128 CPUs
```

`md0_raid5` is pinned. The eleven workers it feeds have obvious headroom. The
whole parity path uses about 6 of 128 logical CPUs while the box is roughly 90%
idle, so this is not a shortage of CPU — it is one thread that everything must
pass through.

Doubling the workers to `gtc=8` did not move it: `md0_raid5` still measured 95.7%.

## Saturation is not the same as a throughput cap

Our first conclusion from that 96.6% was that `gtc=4` must be near optimal,
because the coordinator was already flat out and more workers could not help. That
was wrong, and the next measurement said so: `gtc=8` raised the cold allocating
write from 6083 to 8892 MiB/s, +46%, with `md0_raid5` sitting at the same ~96%.

The error was assuming a saturated thread implies fixed throughput. It only does
if the thread's cost *per byte* is fixed. It isn't. `md0_raid5` hands batches of
stripes to the workers, and when there are more workers draining stripes faster,
each pass retires a larger batch — so the same 96% of one core coordinates
substantially more data. The thread is busy either way; what changes is how much
work each unit of its busy-ness represents.

This is the useful form of the lesson: **"thread X is at 100%" identifies where
the serialisation is, not how much throughput is available.** To learn the second
thing you have to change something and measure again.

## Where the ceiling does bind

It binds hardest where the number of stripe heads per byte is highest, which means
small random writes. The pattern in the results is consistent with that:

| Workload | Best config | Behaviour past that point |
|---|---|---|
| Sequential writes, 1M and larger | `gtc=8` or higher | still climbing at 16 on some tests |
| Random write, 64K qd32 | `gtc=8` | flat |
| Random write, 4K qd64 | `gtc=8` (805 MiB/s) | **regresses** to 751 at `gtc=16` |
| Mixed 70/30 read-write, 4K qd64 | `gtc=8` | regresses, and p99 rises 651µs → 847µs → 954µs as threads double at `scs=16384` |

A 4 KiB write touches one stripe and needs the full read-modify-write cycle, so
the coordinator does nearly as much work per I/O as it does for a 4 MiB write that
covers many complete stripes. Large sequential writes amortise the coordinator
across far more data, which is why they keep scaling and small random writes do
not.

If small random writes ever become a real workload on `/cluster` rather than a
benchmark row, tuning cannot fix this. The escapes are architectural: more arrays,
so there is more than one `md0_raid5` — two three-drive RAID5s would give two
coordinators — or RAID10, which has no parity to coordinate. For the streaming
reads and writes this host actually exists to serve, the coordinator is not the
binding constraint and none of that is worth doing.

## Why we stopped at 8

`gtc=16` won the 1M unaligned and 4M sequential writes decisively — 11434 and
11979 MiB/s against 8497 and 8655 at `gtc=8`, roughly +35%. On the strength of
those two numbers, sixteen looks like the answer.

It is not, for two reasons.

The first is that the same column is internally inconsistent. At `gtc=16`, the
1280K stripe-aligned write — exactly four complete 320 KiB stripes, the one
pattern that needs *no* read-modify-write at all — measured 7443 MiB/s, while the
1M unaligned write, which straddles stripe boundaries and must do RMW, measured
11434. The pattern doing strictly more work was 54% faster. That cannot be a real
effect, so something in that column is noise, and once you accept that you cannot
pick and choose which numbers in it to believe.

The second is that where `gtc=16` loses, it loses on latency and on mixed
workloads, which is what an NFS server actually serves. Peak sequential bandwidth
on an idle box is the least representative thing we measured.

There is a plausible mechanism for the noise growing with thread count.
`raid5wq` is an unbound workqueue whose workers are allocated per NUMA node based
on the submitting CPU. Across two samples we saw the pool land entirely on node 1
once and split across both nodes another time. At `gtc=16` that is 32 workers whose
position relative to the drives and to the parity buffers is decided afresh on
each run, and cross-socket traffic for the XOR is exactly the kind of thing that
swings large-block write throughput by tens of percent.

So eight is chosen as the point where every metric is at or near its best and none
has regressed — not as a demonstrated maximum. Settling 8 against 16 honestly
needs repeated interleaved runs, which
[compare-md-settings.md](../how-to/compare-md-settings.md) supports via
`REPEATS=3`. We judged that an hour of array time was not worth spending to
possibly gain sequential bandwidth we have no workload for yet.

## A note on NUMA pinning

We looked at whether the workers should be pinned closer to the drives.
`raid5wq` exposes `cpumask`, `affinity_scope` and `affinity_strict` under
`/sys/devices/virtual/workqueue/raid5wq/`, so it is tunable, and md is already
NUMA-aware in the sense that it groups workers per node by submitting CPU.

We did not pin, because a RAID5 stripe spans drives attached to both sockets. Any
placement that is local to some of the six members is remote to the others, so
there is no assignment that localises the data path — only assignments that trade
which half pays. `affinity_scope` is already `cache`, which on this CPU is
equivalent to `numa`.

One correction worth recording, because it invalidated an earlier read of this:
CPU enumeration on this host is *interleaved*, node 0 taking the even CPUs and
node 1 the odd ones. An earlier analysis assumed contiguous ranges and therefore
mislabelled which node every thread was on. The layout is in
[hardware.md](../reference/hardware.md); anything deriving a NUMA node from a CPU
number should read `/sys/devices/system/node/node*/cpulist` rather than
arithmetic.
