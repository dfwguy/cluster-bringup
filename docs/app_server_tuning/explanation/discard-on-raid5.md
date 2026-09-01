# Why TRIM was off, and what turning it on bought

`/cluster` had never issued a discard in its life. The filesystem reported tens of
terabytes free; the drives believed every block they had ever been handed was
still live. `nvme list` showed one member at 7.68 TB used of 7.68 TB.

## The kernel refuses discard on RAID5 by default

`md`'s RAID5 implementation carries a module parameter,
`raid456.devices_handle_discard_safely`, which defaults to `N`. While it is `N`,
`/sys/block/md0/queue/discard_max_bytes` reads 0, the block layer advertises no
discard support, and `fstrim` on the filesystem above is a no-op that reports
success.

The reason is a real correctness concern, not conservatism for its own sake. RAID5
parity must stay consistent with data. If the array discards a data chunk and the
drive returns *anything other than the same bytes every time* on a subsequent read
of that discarded region, parity no longer matches and the array silently holds
corrupt redundancy — which surfaces later as bad reconstruction during a rebuild,
the worst possible time. Some SSDs return whatever is convenient after a discard.
The kernel cannot tell them apart, so it assumes the worst and requires an
administrator to assert otherwise.

## Why it is safe on these drives

NVMe reports this behaviour directly, in the `dlfeat` field of `nvme id-ns`. These
Micron 9550 PRO drives report:

```
dlfeat  : 9
```

`9` is `0b1001`. The low three bits are the Deallocated Logical Block Read
Behavior field, and `001` there means "read as all zeros" — deterministic, the
same value on every read. (Bit 3, also set, is the separate Write Zeroes
Deallocate capability, which is not what the parity argument rests on.) Reading
back as zeros is exactly the guarantee RAID5 needs: the kernel can compute
parity over a discarded chunk knowing what it will read.

So the safety argument is not "we tested it and nothing broke". It is that the
drives make an explicit standards-defined guarantee, and
`devices_handle_discard_safely=Y` is the mechanism the kernel provides for telling
it that guarantee holds. This is the intended use of the parameter.

## What it bought, and what it did not

`fstrim -v /cluster` reclaimed approximately 34.9 TiB — effectively the whole
array, since nothing real had ever been written to it. Drive-reported usage
dropped accordingly.

It is worth being precise about what that number means, because it is easy to
oversell. Reclaiming space the filesystem already considered free does not create
capacity. What it does is give the drives' flash translation layer back its
overprovisioning: with every block marked live, garbage collection has no free
erase blocks to work with, so sustained writes eventually stall behind
read-modify-erase cycles inside the drive.

We did not observe that stall, and we should not claim we prevented it. The array
was new, and the write regression we *did* see in the same window turned out to
have a completely different cause — the md tunables being reset, documented in
[tunables-that-do-not-persist.md](tunables-that-do-not-persist.md). TRIM's benefit
here is insurance against future write-cliff behaviour under sustained load, not a
measured improvement. None of the numbers in
[results.md](../reference/results.md) are attributable to it.

The honest summary is that TRIM was a latent problem with a real cost that had not
yet been paid, and it is now fixed.

## It is not persistent yet

The runtime fix works and survives until reboot. Making it survive a reboot cannot
be done on this host, because the module parameter has to be set before or as
`raid456` loads, and this host does not load `raid456` from anything it controls —
see [pxe-boot-and-local-config.md](pxe-boot-and-local-config.md). Locally
rebuilding the initramfs and adding a `modprobe.d` drop-in both appear to work and
both do nothing.

The change belongs on the BCM head node, as a kernel command line parameter for
this host's boot configuration. That is an AIC action item and is still open;
[enable-trim.md](../how-to/enable-trim.md) has the exact parameter to hand over
and the runtime workaround to use until it lands.

Until then, every reboot silently reverts discard to disabled, with the same lack
of symptoms as everything else on this page. The check is one command:

```bash
cat /sys/block/md0/queue/discard_max_bytes   # 0 means TRIM is off again
```
