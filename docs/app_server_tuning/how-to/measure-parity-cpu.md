# Measure the parity path's CPU

`mdcpu.sh` reports per-thread CPU for the RAID5 write path, to answer one
question: is the parity path the bottleneck right now?

## Run it

```bash
bash tools/mdcpu.sh            # sample 10s immediately
bash tools/mdcpu.sh 15         # sample 15s
bash tools/mdcpu.sh 15 -w      # wait for a write workload, then sample 15s
```

Read-only. No `sudo`. Safe on a live host.

Use `-w` unless you have already confirmed a write is in flight. It polls for an
`fio` process doing writes, then samples, and prints which job it caught.

## Sample during a write, or the answer is meaningless

RAID5 reads do not enter the parity path — no stripe cache, no XOR, no workers. A
read workload gives 0% on every thread, correctly, and tells you nothing. The
script says so explicitly when it detects one:

```
NOTE: this is a read workload. RAID5 reads skip the parity path,
      so near-zero md CPU below is correct and uninformative.
```

This is not a hypothetical footnote; it is how our first attempt at this
measurement produced a confidently wrong conclusion.

## Reading the output

```
workload:  rand_rw_70_30__4K_qd64 (--rw=randrw)
md0:       group_thread_cnt=4 stripe_cache_size=8192
raid5wq pools: kworker/u257 kworker/u258

THREAD                    TID     %CPU   CPU  NODE
md0_raid5               48961     96.6     3     1
kworker/u257:0+raid5wq 231892     67.8    98     0
...
---
md parity path total: 596.2% == 5.96 of 128 logical CPUs, across 12 threads
  NUMA node 0      344.4%
  NUMA node 1      251.8%
system-wide CPU busy: 1304.7% of 128 CPUs

verdict: SATURATED thread(s) -- this is the bottleneck:
  md0_raid5  96.6%
```

| Line | What it means |
|---|---|
| `md0_raid5` near 100% | The single parity coordinator is saturated. Expected under write load, at any `group_thread_cnt` |
| Workers well below 100% | They have headroom and are waiting on the coordinator |
| `md parity path total` | Whole write path's CPU cost. About 6 of 128 CPUs is normal |
| `system-wide CPU busy` | Context. If this is low, the host is not short of CPU |
| `verdict` | Flags any thread above 85% |

**A saturated `md0_raid5` does not mean throughput is capped.** It was at ~96% at
both `gtc=4` and `gtc=8`, and `gtc=8` was 46% faster. More workers let the
coordinator retire larger stripe batches per pass, so its cost per byte falls while
its CPU stays pinned. Reasoning in
[the-parity-coordinator.md](../explanation/the-parity-coordinator.md).

So the verdict line localises the serialisation. It does not tell you whether
changing something would help — only a before-and-after measurement does that.

## Why it does not just use `ps` or `top`

Two reasons, both of which produced wrong numbers before this script existed.

`ps` reports **lifetime-average** CPU. `md0_raid5` has been alive since the array
was assembled, so its `ps` figure is diluted by hours of idle and understates a
currently-saturated thread badly. This script reads `/proc/<tid>/stat` twice and
takes the delta.

`raid5wq` workers share their worker pools with unrelated work. Pools `u257` and
`u258` also run `flush-259:5` — md0's own buffered writeback — plus `xprtiod` and
`events_unbound`. Charging every pool member to parity would overcount
substantially. The script records a baseline for every pool member, so a worker
that switched jobs mid-sample still has one, but only credits threads whose `comm`
showed `raid5wq` in at least one of the two snapshots.

## NUMA lines

Workers are allocated per NUMA node based on the submitting CPU's node, so the
split varies between runs — we have seen the pool land entirely on node 1 once and
spread across both another time. Both are normal.

CPU enumeration on this host is interleaved, node 0 even and node 1 odd. The script
reads `/sys/devices/system/node/node*/cpulist` rather than assuming contiguous
ranges, which an earlier hand-rolled version got wrong and consequently mislabelled
every thread's node.
