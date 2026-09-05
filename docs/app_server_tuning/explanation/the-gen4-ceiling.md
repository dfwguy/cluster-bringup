# Gen5 drives in Gen4 bays

Reads from `/cluster` measure 40.3 GiB/s and do not budge — not for
`stripe_cache_size`, not for `group_thread_cnt`, not for TRIM, not across eight
configurations spanning a 5.5x range in write throughput. That constancy is the
most informative number in the whole exercise, because it says the read path is
limited by something none of those knobs touch.

## The arithmetic

Six NVMe drives, each on a PCIe Gen4 x4 link. Gen4 runs 16 GT/s per lane with
128b/130b encoding, so a x4 link carries about 7.88 GB/s, which is 7.34 GiB/s.
Across six drives that is **44.0 GiB/s** of theoretical link bandwidth.

Measured: 40.3 GiB/s, or **92% of theoretical**.

For sequential reads through a filesystem, through md, through the block layer,
92% of the raw link is close to the practical maximum. There is no meaningful
headroom being left on the table, and no tuning could find any, because the
constraint is the interconnect rather than anything in software. Parity is not
involved — a RAID5 read is a lookup and a forward — so the read path has almost no
software cost to optimise away in the first place.

## The drives are Gen5. The slots are not.

The drives are Micron 9550 PRO, rated PCIe Gen5 x4. So the obvious reading is that
they have downtrained to Gen4 and something should be done about it. We believed
that, and we were wrong twice in a row.

The first mistake was assuming the platform was Gen5-capable throughout. It is,
in part: this is a Dell PowerEdge R760, and the ConnectX-7 NICs in its riser slots
negotiate Gen5 x16. So the CPUs' root ports do Gen5, which seemed to confirm that
the drives running at Gen4 was a misconfiguration.

The second mistake followed from the first — we recommended escalating a BIOS
change to AIC to force Gen5 on the U.2 bays. That recommendation was wrong and was
withdrawn. **The R760's U.2 NVMe bays are Gen4-only by design.** The backplane and
its PCIe routing to the U.2 bays are Gen4; the Gen5 lanes on that platform go to
the riser slots, which is exactly why the NICs get Gen5 and the drives cannot.
There is no BIOS setting, no firmware update, and no cabling change that makes a
Gen4 backplane into a Gen5 one.

So the drives are running at the fastest link the chassis can give them. Nothing
is misconfigured and nothing is degraded.

## What kind of finding this is

Not a tuning finding. A procurement one: Gen5 drives were bought for a chassis
whose drive bays cannot use Gen5. About half of each drive's sequential read
capability is unreachable in this server and always will be.

That is worth writing down for two audiences. For anyone tempted to re-open this
as a performance problem — it isn't one, the ceiling is structural, and 92% of it
is already being achieved. For whoever specifies the next one of these — either
match the drives to the backplane and save the money, or choose a chassis with
Gen5 U.2 routing if the drives' full bandwidth is actually wanted.

It is also worth being clear that it is not costing us anything today. 40.3 GiB/s
of read bandwidth is far beyond what `bond0` can export: two 200 GbE legs give
400 Gb/s, which is 50 GB/s or about 46.6 GiB/s at the wire, and no realistic NFS
workload will come near that. The array can already read faster than the network
can carry, so the Gen4 ceiling is invisible to every client and only matters to
work done locally on this host.

## The methodological point

We reached the wrong conclusion twice because we reasoned from a component
datasheet and a partial platform observation instead of the platform
documentation. The drives said Gen5; one set of slots did Gen5; therefore all
slots should. Each step was locally reasonable and the conclusion was false, and
it would have cost AIC time chasing a BIOS setting that does not exist.

The check that resolved it was identifying the exact chassis model and reading
what Dell says its U.2 bays do. That is a cheaper first move than any amount of
local investigation, and on a vendor platform it should have been the first move.

The measured link state is recorded in [hardware.md](../reference/hardware.md).
