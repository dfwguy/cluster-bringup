# Measurements

Every number from the eight-configuration sweep of `md0`, 2026-08-27. Columns are
`group_thread_cnt / stripe_cache_size`.

Neutral record. Interpretation is in
[md-write-throughput.md](../explanation/md-write-throughput.md), and the caveats
that decide which of these numbers to trust are in
[benchmarking-this-array.md](../explanation/benchmarking-this-array.md) — read
that before quoting anything here.

## How they were produced

`bench-cluster.sh`, driven by `tune-md.sh`. Raw `fio` JSON is under
`/cluster/bench/_sweep/gtc<N>_scs<M>/`.

| Parameter | Value |
|---|---|
| Tool | `fio` 3.36, `libaio` engine |
| Dataset | 8 files × 8 GiB = 64 GiB, in `/cluster/bench` |
| Jobs | `--numjobs=8`, `--group_reporting` |
| Queue depth | 16 for sequential, 32-64 for random, 1 for latency tests |
| I/O mode | `--direct=1` throughout — bypasses page cache **and readahead** |
| Duration | 45 s per test, `--ramp_time=5` |
| Per configuration | 10.1 min of `fio`, plus ~1 min dataset layout |
| Dataset handling | rewritten in full at the start of every configuration |

All four sequential write tests use identical parameters and differ only in block
size, so differences between them are not a test-setup artefact.

## Test definitions

| Test | Pattern | Why it is here |
|---|---|---|
| `cold_allocating_write__1280K` | 1280 KiB sequential write | Creates the dataset. Pays XFS extent allocation, so **not comparable** with the overwrite tests below |
| `seq_write__1280K_aligned` | 1280 KiB = 4 full stripes | Best case: no read-modify-write required |
| `seq_write__1M_unaligned` | 1 MiB, straddles stripes | Realistic large write; must do read-modify-write |
| `seq_write__320K_1_stripe` | 320 KiB = exactly 1 stripe | Smallest write that can avoid read-modify-write |
| `seq_write__4M` | 4 MiB | Streaming write |
| `seq_read___*` | 1280 KiB / 1 MiB / 4 MiB | Read path — never touches parity |
| `rand_write__4K_qd64` | 4 KiB random, qd64 | Worst case for RAID5: one stripe touched per I/O |
| `rand_write__64K_qd32` | 64 KiB random, qd32 | One chunk per I/O |
| `rand_rw_70_30__4K_qd64` | 70% read / 30% write, 4 KiB | Mixed, closest to a metadata-ish load |
| `qd1_*` | Single outstanding request | Latency floor, nothing to hide behind |

The aligned and unaligned variants exist as a consistency check as much as a
measurement: aligned should never lose to unaligned, so if it does, the run is
suspect.

## Bandwidth, MiB/s — higher is better

```
TEST                              gtc0/256  gtc0/8192  gtc2/8192  gtc4/8192  gtc4/16384  gtc8/8192  gtc8/16384  gtc16/16384
-------------------------------- --------- ---------- ---------- ---------- ----------- ---------- ----------- ------------
cold_allocating_write__1280K          1158       1701       3725       6083        6039       8892        8518         8244
seq_write__1280K_aligned              1447       1707       5372       5719        6676       8517        7741         7443
seq_write__1M_unaligned               1476       1421       5618       5650        5673       8944        8497        11434
seq_write__320K_1_stripe              1577       1380       3619       5266        5430       5382        8187         6384
seq_write__4M                         1527       1425       3859       5968        7646       8606        8655        11979
rand_write__4K_qd64                    241        257        672        750         754        667         805          751
rand_write__64K_qd32                   411        391        733       1046        1012       1145        1114         1134
rand_rw_70_30__4K_qd64                 502        592       1278       1577        1546       1747        1679         1489
qd1_rand_write__4K                      34         33         32         33          30         32          30           30
seq_read___1280K_aligned             41340      41306      41288      41263       41254      41292       41282        41285
seq_read___1M                        41336      41307      41287      41275       41250      41282       41273        41249
seq_read___4M                        41331      41318      41289      41285       41255      41261       41281        41280
qd1_seq_read____1M                    3898       3456       3726       3917        3759       3887        3990         4079
```

## p99 latency, microseconds — lower is better

```
TEST                              gtc0/256  gtc0/8192  gtc2/8192  gtc4/8192  gtc4/16384  gtc8/8192  gtc8/16384  gtc16/16384
-------------------------------- --------- ---------- ---------- ---------- ----------- ---------- ----------- ------------
cold_allocating_write__1280K        152043     145752      68681      38010       37486      24248       24248        20840
seq_write__1280K_aligned            114819     145752      60030      40632       35389      24248       22937        23724
seq_write__1M_unaligned              88604     135266      68681      33816       32112      19529       17694        15400
seq_write__320K_1_stripe             28704      41156      16449      12124       11993      10158        8454         9109
seq_write__4M                       333447     442499     162529      89653       79167      61079       64225        58982
rand_write__4K_qd64                  11599      10813       5996       4685        4882       4554        4292         4423
rand_write__64K_qd32                 46399      42205      20840      18743       20316      12386       13041        12517
rand_rw_70_30__4K_qd64                1384        313        485        651         651        618         847          954
qd1_rand_write__4K                     125        128        134        134         142        132         142          142
seq_read___1280K_aligned              7241       6258       6782       6782        6848       6848        6979         6914
seq_read___1M                         6848       5472       5996       5996        6127       6193        6193         6193
seq_read___4M                        15400      14483      15138      15138       15138      15269       15269        15269
qd1_seq_read____1M                     259        305        272        264         272        264         257          242
```

## Chosen configuration against kernel defaults

`gtc=8, scs=16384` versus `gtc=0, scs=256`:

| Test | Default | Tuned | Change |
|---|---|---|---|
| `seq_write__1280K_aligned` | 1447 | 7741 | **5.35x** |
| `seq_write__1M_unaligned` | 1476 | 8497 | **5.76x** |
| `seq_write__320K_1_stripe` | 1577 | 8187 | **5.19x** |
| `seq_write__4M` | 1527 | 8655 | **5.67x** |
| `rand_write__4K_qd64` | 241 | 805 | 3.34x |
| `rand_write__64K_qd32` | 411 | 1114 | 2.71x |
| `rand_rw_70_30__4K_qd64` | 502 | 1679 | 3.34x |
| `seq_read___1M` | 41336 | 41273 | 1.00x |
| `seq_write__4M` p99 | 333447 µs | 64225 µs | **−81%** |
| `seq_write__1280K_aligned` p99 | 114819 µs | 22937 µs | **−80%** |

Sequential writes average about **5.5x**. Reads do not change, and cannot — see
[the-gen4-ceiling.md](../explanation/the-gen4-ceiling.md).

## Known-untrustworthy entries

Single sample per configuration. One ordering violation is visible and bounds the
noise:

| Config | Aligned 1280K | Unaligned 1M | Problem |
|---|---|---|---|
| `gtc16/16384` | 7443 | 11434 | Unaligned is 54% **faster** than aligned. Impossible |
| `gtc8/16384` | 7741 | 8497 | Same inversion, 10% |
| `gtc8/8192` | 8517 | 8944 | Same inversion, 5% |
| `gtc4/8192` | 5719 | 5650 | Correct ordering |

The inversion grows with thread count. Treat large-sequential-write differences
below roughly 50% at `gtc ≥ 8` as unresolved. `REPEATS=3` in
[compare-md-settings.md](../how-to/compare-md-settings.md) is the fix; it has not
been run.

## Parity-path CPU

From `mdcpu.sh`, sampled during writes.

| Config | Workload | `md0_raid5` | Workers | Total parity CPU |
|---|---|---|---|---|
| `gtc=4` | `rand_rw_70_30__4K_qd64` | **96.6%** | 11 threads, 25-68% each | 596% of 12800% |
| `gtc=8` | `cold_allocating_write__1280K` | **95.7%** | 8 threads, 37-40% each | 405% of 12800% |

`md0_raid5` is saturated in both. System-wide CPU was 1305% and 1630% of 12800%
respectively, so the host was roughly 90% idle while the parity path was
bottlenecked. Read workloads show 0% on every parity thread, correctly.

## TRIM

| Measurement | Value |
|---|---|
| `discard_max_bytes` before | 0 (discard unsupported) |
| `discard_max_bytes` after | 2199023255040 |
| `fstrim -v /cluster` reclaimed | ~34.9 TiB |
| Drive `dlfeat` | 9 |

No performance measurement is attributable to TRIM; reasoning in
[discard-on-raid5.md](../explanation/discard-on-raid5.md).
