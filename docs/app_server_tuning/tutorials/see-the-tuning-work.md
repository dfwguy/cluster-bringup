# See the tuning work

A guided tour of the `/cluster` array's tuning. You will read its live
configuration, watch the kernel threads that do the work, and find the same
numbers in the recorded results.

Read-only throughout. Nothing here changes a setting, writes to `/cluster`, or
affects NFS clients. Follow it on the live host.

You need shell access to `appserver-nc`. No `sudo`. About fifteen minutes.

## 1. Look at the array

```bash
cat /proc/mdstat
```

```
md0 : active raid5 nvme2n1p1[0] nvme6n1p1[6] nvme5n1p1[4] nvme3n1p1[3] nvme1n1p1[2] nvme4n1p1[1]
      37506652160 blocks super 1.2 level 5, 64k chunk, algorithm 2 [6/6] [UUUUUU]
```

Six NVMe partitions in a RAID5. `[6/6] [UUUUUU]` means all six present and healthy
— check this first, always. `64k chunk` is the important number.

RAID5 stores data in stripes across the members, with one chunk of parity per
stripe. Six members, so five hold data in any given stripe, so a full stripe is
5 × 64 KiB = **320 KiB**. Keep that number.

Now the tunables:

```bash
cd /sys/block/md0/md
cat group_thread_cnt stripe_cache_size
```

You should see `8` and `16384`. The kernel defaults are `0` and `256`. Both of
those are deliberate changes, and between them they are worth about 5.5x on
sequential writes.

## 2. Understand why writes need CPU at all

This is the idea the rest of the tutorial rests on.

To write a full 320 KiB stripe, the kernel has all five data chunks, XORs them for
parity, and issues six writes. Cheap.

To write *less* than a stripe, it cannot compute parity from what it has. It must
first read the chunks it is not overwriting, then XOR, then write. One logical
write becomes two reads and two writes. That is the read-modify-write penalty, and
it is why the write path needs threads and cache.

Reads have no equivalent. A RAID5 read is a lookup and a forward — no parity, no
XOR, no threads.

Before continuing, predict one thing: if you tune the write path and then measure
reads, what should happen to the read numbers? Hold that prediction until step 4.

## 3. Watch the threads while a write happens

Two terminals. In the first, start a write on the benchmark scratch area — this
writes only to `/cluster/bench`, never to real data:

```bash
ONLY='seq write, 4M' RUNTIME=60 bash tools/bench-cluster.sh
```

If `/cluster/bench` does not exist or `fio` is missing, skip to step 4 and read the
sample output there instead.

In the second terminal, while that runs:

```bash
bash tools/mdcpu.sh 15 -w
```

`-w` waits for a write workload before sampling. You will see something like:

```
md0_raid5               48961     95.7    19     1
kworker/u258:4+raid5wq 235187     40.5    77     1
kworker/u258:3-raid5wq 219807     40.0    83     1
... six more workers, 36-40% each
---
md parity path total: 405.5% == 4.05 of 128 logical CPUs, across 9 threads
system-wide CPU busy: 1630.4% of 128 CPUs
```

Three things to notice.

`md0_raid5` is at about 96%. There is exactly one of it per array, and no setting
changes that — it coordinates every stripe. It is the serialisation point in the
write path.

The `raid5wq` workers are at 40%, not 100%. They are the threads
`group_thread_cnt=8` created. They have headroom; they are waiting on the
coordinator.

The parity path uses about 4 of 128 logical CPUs while the host is roughly 87%
idle. This is not a CPU shortage. It is one thread everything passes through — a
completely different problem, with completely different fixes.

Now the counterintuitive part, which is the single most useful thing in this
tutorial: `md0_raid5` sits at ~96% at `group_thread_cnt=4` **and** at `8`, yet 8 is
46% faster. A saturated thread does not imply capped throughput. With more workers
draining stripes, the coordinator retires bigger batches per pass, so its cost per
byte drops while its CPU stays pinned.

Take from this: *"thread X is at 100%" tells you where the serialisation is, not
how much performance is available.* For the second question you must change
something and measure again.

## 4. Sample during a read, and get nothing

Wait for the write to finish, then start a read and sample it:

```bash
ONLY='seq read,  1M' RUNTIME=60 bash tools/bench-cluster.sh
```

```bash
bash tools/mdcpu.sh 10
```

Near-zero on every parity thread, and a note saying the numbers are uninformative.
That is your step-2 prediction confirmed: reads never enter the parity path.

This is worth having done once, because it is a real trap. The first time we tried
to find out whether the coordinator was saturated, we sampled during a read, got
0%, and concluded the parity path was idle. The measurement was correct; the
question was wrong.

## 5. Find the numbers in the record

No benchmarking needed — the sweep is saved:

```bash
bash tools/tune-md.sh -r
```

Read-only; it runs no tests. Eight configurations, thirteen tests each.

Look at the `seq_write__1280K_aligned` row, left to right: 1447 MiB/s at kernel
defaults, rising to 7741 at `gtc=8, scs=16384`. Then the `seq_read___1M` row:
41336 down the entire width of the table, unchanged in every configuration.

That flat read row is the Gen4 ceiling. The drives are Gen5-capable, but the R760's
U.2 bays are Gen4 by design, giving 44.0 GiB/s across six drives. The measured
40.3 GiB/s is 92% of that. There is nothing to tune, which is exactly why nothing
you could tune moved it.

Then compare the `gtc0/8192` column against `gtc0/256`: raising the cache 32-fold
with the thread count still at 0 bought 18% on that row, and went *negative* on
several others. The cache everyone reaches for first was almost irrelevant; the
threads were the whole story. Growing a queue in front of a single server does not
increase throughput.

Finally, in the `gtc16/16384` column, compare `seq_write__1280K_aligned` (7443)
with `seq_write__1M_unaligned` (11434). Aligned covers four complete stripes and
needs no read-modify-write. Unaligned straddles stripes and must do it. The
harder pattern measured 54% faster.

That is impossible, so something in that column is noise — which is why the chosen
value is 8 and not 16, and why every number in that table is a single sample
awaiting a repeated run.

## What you now know

- `/cluster` is a 6-drive RAID5, 320 KiB full stripe, and alignment to it decides
  whether a write is cheap or expensive.
- Writes cost CPU because of parity; reads cost none, which is why tuning moves
  one and not the other.
- One coordinator thread serialises the write path, and its being saturated
  localises the bottleneck without bounding the throughput.
- Threads were the lever, cache was not.
- Reads are at 92% of a structural ceiling and are not a tuning target.
- Results that violate a known ordering are telling you about the harness.

## Next

- [apply-md-tuning.md](../how-to/apply-md-tuning.md) — check and set the values,
  and what silently resets them
- [md-write-throughput.md](../explanation/md-write-throughput.md) — the full
  argument, including how an unmeasured value survived review
- [the-parity-coordinator.md](../explanation/the-parity-coordinator.md) — the
  coordinator ceiling, and 8 against 16
