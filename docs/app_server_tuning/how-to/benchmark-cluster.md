# Benchmark `/cluster`

`bench-cluster.sh` characterises the array with `fio`. Use it to verify a tuning
change, or to get a baseline before one.

## Cost, before you start

It writes. Do not run it while anything real is using `/cluster`.

| | |
|---|---|
| Duration | about 11 minutes for the full suite |
| Space | 64 GiB in `/cluster/bench`, left in place afterwards |
| Load | 8 concurrent `fio` jobs, saturates the array |
| Reads | 40 GiB/s sustained — will also saturate the parity path on writes |

## Prerequisites

```bash
sudo apt install fio jq
sudo mkdir -p /cluster/bench
sudo chown $USER /cluster/bench
```

`libaio` must be available as an `fio` engine; the script checks and refuses to
start without it.

## Run it

```bash
bash tools/bench-cluster.sh
```

Prints a preflight block — `fio` version, engine, dataset size, free space,
detected stripe geometry, and the array's current tunables — then each test as it
finishes, then a summary table. Raw JSON goes to `/cluster/bench/_results/`.

Record the tunables from the preflight block alongside any result you keep. A
number without them is not interpretable.

### Run a subset

`ONLY` is a regex on the test label:

```bash
ONLY='write|70/30' bash tools/bench-cluster.sh
```

The dataset layout pass is exempt and always runs, because it is what creates the
files every other test reads.

### Other knobs

| Variable | Default | Effect |
|---|---|---|
| `ONLY` | unset | Regex filter on test labels |
| `RUNTIME` | 45 | Seconds per test |
| `RESULTS` | `/cluster/bench/_results` | Where JSON goes |
| `BENCH_DIR` | `/cluster/bench` | Dataset location |

### Clean up

```bash
bash tools/bench-cluster.sh -c
```

Clears the dataset but keeps the directory and its ownership.

## Reading the output

**The first write is not comparable with the rest.** `cold allocating write` is
the dataset layout pass; it allocates blocks that do not exist yet and pays XFS
extent allocation. Everything below it overwrites already-allocated blocks. The
script prints this warning inline. Compare allocating writes only against other
allocating writes.

**Reads will be about 40.3 GiB/s and will not respond to anything.** That is the
PCIe Gen4 ceiling on the U.2 bays, at 92% of theoretical. A read result that has
not changed after a tuning change is the expected outcome, not a failed
measurement. See [the-gen4-ceiling.md](../explanation/the-gen4-ceiling.md).

**Check that aligned beats unaligned.** `seq write, 1280K aligned` covers four
complete 320 KiB stripes and needs no read-modify-write; `seq write, 1M unaligned`
straddles stripes and does. Aligned should win. If it loses, the run has more noise
in it than signal and the numbers should not be used — this has happened, at
`gtc=16`, by 54%. Details in
[benchmarking-this-array.md](../explanation/benchmarking-this-array.md).

**`--direct=1` means readahead is not being tested.** `read_ahead_kb` cannot
affect any number this script produces. It matters only for the buffered path that
NFS clients use, which this script does not exercise at all.

## Comparing against the recorded baseline

[results.md](../reference/results.md) has the full eight-configuration matrix from
2026-08-27, taken with this script at `RUNTIME=45`. To compare, match the tunables
and the runtime, and expect roughly:

| Test | At `gtc=8, scs=16384` |
|---|---|
| `seq write, 1280K aligned` | 7.5-8.5 GiB/s |
| `seq write, 4M` | 8.5 GiB/s |
| `seq read, 1M` | 40.3 GiB/s |
| `rand write, 4K qd64` | 800 MiB/s |

A sequential write result near 1.4 GiB/s means the array is at kernel defaults —
go to [apply-md-tuning.md](apply-md-tuning.md).

## Sweeping several configurations

Do not loop this script by hand. [compare-md-settings.md](compare-md-settings.md)
covers `tune-md.sh`, which applies each configuration, runs the subset, restores
the production values on exit even on Ctrl-C, and prints a comparison matrix.
