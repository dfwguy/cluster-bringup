# Four ways our own benchmarks lied

Every number in [results.md](../reference/results.md) comes from `fio` runs that
we wrote, ran and initially misread. The bugs were all in the harness or the
interpretation rather than the tool. They are recorded here because each one
produced a plausible, confident, wrong answer, and the next person measuring this
array will hit the same four.

## 1. The first write is not like the others

The benchmark creates its dataset by writing 64 GiB, then runs a series of write
tests over those files. The dataset-creation pass was originally reported
alongside the others as just another sequential write result, and it was
consistently the slowest.

It is not comparable. That pass allocates blocks that do not exist yet, so it pays
XFS extent allocation and first-write costs. Every later test overwrites blocks
that already exist. Comparing them is comparing allocation against overwrite and
attributing the difference to whatever tunable changed.

Worse, the very first configuration we tested was the only one where the
stripe-aligned write happened to *be* the allocating pass, so the one test
designed to show RAID5 at its best was measured under the one condition that
handicaps it.

The harness now labels that pass `cold allocating write`, exempts it from the
comparison set, and prints a note saying it is not comparable with the writes
below it. It is still reported, because allocation throughput is a real thing
worth knowing — just not in the same column as overwrites.

## 2. Read tests tell you nothing about the parity path

Our first attempt to measure whether `md0_raid5` was saturated returned 0.0% CPU
on every parity thread, and we briefly took that as evidence the parity path was
idle and therefore not the bottleneck.

The sampler was running during a read test. RAID5 reads do not enter the parity
path at all — no stripe cache, no XOR, no worker threads. Zero was the correct
answer to a question we had not meant to ask.

`mdcpu.sh` now takes a `-w` flag that waits for a write workload before sampling,
prints which `fio` job it caught, and says explicitly when it has landed on a read
workload and the numbers are therefore uninformative.

The same asymmetry is why reads are flat across every configuration in the
results, and why any future tuning work on this array should treat read and write
measurements as answering completely different questions.

## 3. `--direct=1` silently removes a variable

Every test uses direct I/O, which bypasses the page cache and, with it,
readahead. This is what makes the results reproducible, and it also means
`read_ahead_kb` cannot affect any number in this document.

That cuts both ways. It is a relief when interpreting the sweep — `read_ahead_kb`
was at the wrong value for part of it, and it provably did not matter. It is a
problem when generalising: the buffered path is what NFS clients actually use, and
nothing here measures it. Any claim about `read_ahead_kb` in these results is
outside what was measured.

## 4. One sample per configuration is not enough at high thread counts

The clearest instance: at `gtc=16`, the 1280K stripe-aligned write — four complete
stripes, needing no read-modify-write — measured 7443 MiB/s, while the 1M
unaligned write, which straddles stripes and must do read-modify-write, measured
11434. The pattern doing strictly more work was 54% faster.

That is not a physically possible ordering, so at least one of those numbers is
scatter, and the spread between them bounds the noise at something like tens of
percent. Both were single samples. Both looked authoritative in a formatted table
with a percentage next to them.

The tell was internal inconsistency, not implausibility in isolation. 11434 MiB/s
is a perfectly believable number; it only becomes suspect next to the aligned
result from the same run. Which means the practical defence is to include tests
whose relative ordering is known in advance, so that a violated ordering flags the
run — the aligned and unaligned variants now serve that purpose whether or not
anyone is interested in alignment per se.

`tune-md.sh` grew a `REPEATS=N` mode in response. It interleaves rounds — every
configuration once, then again — rather than repeating each configuration back to
back, because consecutive repeats share whatever the array was doing at that
moment and would agree with each other while disagreeing with the next
configuration. It reports medians with the min-max spread beside them, so a column
whose single-run numbers cannot be trusted is visible as a large spread rather
than invisible.

We have not yet run it. The 8-versus-16 question in
[the-parity-coordinator.md](the-parity-coordinator.md) is the one open decision
that depends on it.

## What to carry forward

Two habits, both cheap:

Report the ordering you expect before you look. Alignment tests, read-versus-write
asymmetry and thread-count monotonicity all have predictable directions, and a
result that violates one is telling you about your harness, not your hardware.

Distrust any single-sample comparison whose margin is smaller than the largest
unexplained inconsistency in the same dataset. On this array, that threshold is
currently around 50% for large sequential writes at high thread counts, which is
uncomfortably wide and is the strongest argument for doing the repeated run.
