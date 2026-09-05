# Why the tuning vanished

On 2026-08-26 the array was correctly tuned. On 2026-08-27 it was running at
kernel defaults, sequential writes were down 74-81%, and nothing anywhere had
recorded that this happened. This is the most expensive finding in this document,
and the least technically interesting: it is a lifecycle bug, not a performance
one.

## Where the settings actually live

The md tunables are files under `/sys/block/md0/md/`. That path looks like it
belongs to a device, and it does not — it belongs to an *assembled array
instance*. `md0` is a software construct that the kernel builds when the array is
assembled and destroys when it is stopped. Its sysfs directory, and everything
configured in it, is created fresh each time with kernel defaults.

So this sequence loses the tuning:

```
mdadm --stop /dev/md0          # sysfs directory destroyed
mdadm --assemble /dev/md0 ...  # recreated: group_thread_cnt=0, stripe_cache_size=256
```

`appserver-tuning.service` sets these at boot, and boot is the only time it runs.
An array re-assembled at 14:00 comes back untuned and stays that way until
someone reboots the host or re-runs the script by hand.

`enable-trim.sh` stops and re-assembles the array — that is precisely how it
applies the `raid456` module parameter without a reboot. It did its job correctly
and left the array de-tuned as a side effect nobody had thought about.

## Why nobody noticed for a day

Every signal you would normally trust said the array was fine.

`/proc/mdstat` reported `[UUUUUU]` clean, because it was. The filesystem mounted,
the NFS exports came back, `df` was correct, no dmesg line was emitted. Reads ran
at 40.3 GiB/s, completely unaffected, because RAID5 reads never touch the parity
path and the parity path is the only thing that was broken. Nothing logs the value
of a sysfs tunable, and nothing compares it against an intended value.

The one visible symptom was write throughput, on a host with no production
workload, whose baseline had been measured once, days earlier, under conditions
that had since changed. We initially attributed the regression to the `fstrim`
that had run in between — a plausible story that happened to be wrong, and that
we only abandoned after reading `appserver-tuning.sh` and noticing it declared
values the live array did not have.

That is the part worth generalising. **A setting with no reader is a setting that
can be silently lost.** The tuning had an author, an installer and a rationale,
and no verifier.

## The fix, and why it takes the shape it does

`enable-trim.sh` now snapshots the three values during preflight, before it stops
anything, and re-applies them immediately after re-assembly — before the mount, so
`/cluster` is never exported from a de-tuned array. The rollback path does it too,
on the principle that restoring service on a de-tuned array is only half a
rollback.

It snapshots the *live* values rather than re-reading them from
`appserver-tuning.sh`. That choice matters:

- Parsing the boot script would create a second place the numbers are written
  down, free to drift from the first.
- Whatever was in effect before the script ran is, by definition, what should be
  in effect after it. The script's job is to change the discard parameter and
  change nothing else.

The corresponding trap is that snapshotting faithfully preserves a bad state: if
the array was *already* de-tuned when the script started, it will be de-tuned
after. So the script checks whether what it captured looks like kernel defaults
(`group_thread_cnt=0` or `stripe_cache_size=256`) and warns that re-applying them
preserves a de-tuned array. Re-applying is still the right default — silently
"correcting" to values the operator did not ask for would be worse — but it says
so out loud.

The re-apply verifies by reading back, and reports a mismatch with the command to
run. A fix that can fail silently is the same class of bug as the one being fixed.

We also deleted a staged `md-tuning.service` that would have applied these values
from a systemd unit. It was never installed, and it hardcoded `GROUP_THREADS=4`
and `STRIPE_CACHE=16384` in `Environment=` lines — a second copy of exactly the
number that had just gone stale. `appserver-tuning.sh` is the single source of
truth, and the way to keep it that way is to not have two.

## What is still not covered

The fix is specific to `enable-trim.sh`. Anything else that stops the array — a
manual `mdadm --stop`, a disk replacement, an `mdadm --grow`, a future script
written by someone who has not read this page — loses the tuning in exactly the
same way, with exactly the same absence of symptoms.

The general fix is a verifier: something that periodically compares the live
values against the intended ones and complains. That is a natural fit for a BCM
health check or an `auto-action-trigger` check, since that framework already
exists on this cluster to notice things that have quietly stopped being true. It
is not written yet, and until it is, this failure mode is prevented by
documentation rather than by machinery — which is to say, not really prevented.

[apply-md-tuning.md](../how-to/apply-md-tuning.md) has the by-hand check to run
after anything touches the array.
