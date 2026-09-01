# Compare md0 settings

`tune-md.sh` applies a list of `group_thread_cnt`/`stripe_cache_size`
combinations, benchmarks each, and prints a comparison matrix. It restores the
production values when it exits, including on Ctrl-C.

Use it to re-open the tuning question. To just set the values, use
[apply-md-tuning.md](apply-md-tuning.md).

## Cost

About 11 minutes per configuration per repeat, and it saturates the array
throughout. The default run is two configurations, so roughly 22 minutes.

## Run it

```bash
bash tools/tune-md.sh                       # defaults: 8:16384 16:16384
bash tools/tune-md.sh 4:16384               # one configuration
bash tools/tune-md.sh 4:8192 8:8192 8:16384 # any list
bash tools/tune-md.sh -r                    # report only, runs nothing
```

Arguments are `group_thread_cnt:stripe_cache_size`. Needs `sudo` for the sysfs
writes and prompts once.

The report always covers **every** configuration ever measured, by reading the
saved JSON under `/cluster/bench/_sweep`, so running one configuration still
produces a full comparison against the recorded sweep.

## Measure variance — do this before believing a close result

```bash
REPEATS=3 bash tools/tune-md.sh 8:16384 16:16384
```

Rounds are interleaved — every configuration once, then again — rather than
repeated back to back, because consecutive repeats of one configuration share
whatever the array was doing at that moment and would agree with each other while
disagreeing with the next configuration.

With repeats, an extra section appears reporting the median per configuration with
the min-max spread beside it:

```
seq_write__1M_unaligned              8497 +/-6%          11434 +/-41%
```

A large spread means that column's single-run numbers are not trustworthy. This is
the tool for settling `gtc=8` against `gtc=16`, which the single-sample sweep could
not — see
[benchmarking-this-array.md](../explanation/benchmarking-this-array.md).

## Restore behaviour, and the trap

On exit the script restores the values that `appserver-tuning.sh` **declares**, not
the values it found running. That is deliberate: if the array was already de-tuned
when you started, restoring what was found would preserve the de-tuned state.

It prints a warning when the live values disagree with the script:

```
WARNING: live values do not match appserver-tuning.sh.
WARNING: the array was almost certainly reassembled without re-tuning.
```

The trap is the other direction. If you are testing a value you have *not* yet
written into `appserver-tuning.sh`, the restore will undo it:

```bash
RESTORE_GTC=8 bash tools/tune-md.sh 8:16384 16:16384
```

`RESTORE_GTC`, `RESTORE_SCS` and `RESTORE_RA` each override one restored value.

## Reading the matrix

```bash
BASE=gtc4_scs8192 bash tools/tune-md.sh -r
SHOW='gtc(8|16)_scs16384' bash tools/tune-md.sh -r
```

| Variable | Effect |
|---|---|
| `BASE` | Which column percentages are relative to. Default is the leftmost |
| `SHOW` | Regex on column names, to fit a readable number of columns |
| `ONLY_RE` | Which tests to run. Default `write\|70/30\|seq read` |
| `SWEEP_ROOT` | Where per-configuration JSON lives |

Two matrices are printed, bandwidth and p99 latency. Both are worth reading:
`gtc=16` wins some bandwidth rows while losing latency rows, which is most of the
reason it was not chosen.

Sanity checks on any new matrix:

- Read rows should be flat at about 41300 MiB/s across all columns. If they are
  not, something other than md changed between runs.
- `seq_write__1280K_aligned` should beat `seq_write__1M_unaligned` in the same
  column. If it does not, that column is noise.
- `cold_allocating_write__1280K` is a different kind of measurement from the
  `seq_write__*` rows and should not be compared with them.

## If it refuses to start

| Message | Meaning |
|---|---|
| `md0 is degraded or rebuilding` | Refuses to benchmark a resyncing array. Wait for `[UUUUUU]` |
| `stripe_cache_size=N exceeds this kernel's 32768 ceiling` | Lower it; the kernel would clamp silently |
| `jq not installed` | `sudo apt install jq` |
| `no results under /cluster/bench/_sweep` | `-r` with nothing measured yet |
