# Which local changes on this host are real

`appserver-nc` PXE-boots. Its kernel and initramfs come from the BCM head node on
every boot. Its root filesystem is local and persistent. That combination means
some changes you make on this host survive reboots and some are quietly discarded,
and the two categories are not intuitive.

We learned this by making a change that was correct, applying it correctly,
rebooting, and finding it had not been applied.

## What happened

To make TRIM persistent we did what you would do on any Ubuntu host: added a
`modprobe.d` drop-in setting `raid456 devices_handle_discard_safely=Y`, ran
`update-initramfs -u`, and rebooted. After the reboot the parameter was back to
`N`.

The drop-in was still there. The rebuilt initramfs was still in `/boot`, with a
current timestamp. Nothing had reverted anything. The initramfs we rebuilt was
simply never read, because the bootloader that would have loaded it never ran —
the host had already been handed a kernel and an initrd over the network by BCM,
and `raid456` loaded out of *that* initrd, which contains no knowledge of our
drop-in.

`/boot` on this host is a directory that local tooling maintains diligently and
nothing consumes. `update-initramfs` succeeds and is inert. So is GRUB
configuration.

## The dividing line

The useful mental model is *when* a setting is consumed:

| Consumed | Persists locally? | Examples |
|---|---|---|
| Before or during kernel/initramfs load | **No** — comes from BCM | kernel command line, module parameters needed at load time, initramfs hooks, GRUB config |
| After the root filesystem is mounted | **Yes** — local root is persistent | `/etc/sysctl.d/`, `/etc/systemd/system/`, `/etc/exports`, `/usr/local/sbin/`, `/etc/profile.d/` |

We verified the second row rather than assuming it. The sysctl drop-in, the
tuning script, the systemd units and the NFS exports all survived the same reboot
that discarded the initramfs change. The local root filesystem is genuinely
persistent; it is specifically the pre-root boot path that belongs to BCM.

This is why `appserver-tuning.service` is the right shape for the md tunables and
a kernel parameter would not be: it runs after the root filesystem is up, from
local disk, entirely within the persistent half of the table.

## Consequences

**Module parameters that must be set at load time are BCM changes.** There is no
local workaround that survives a reboot. For TRIM this is the open AIC item in
[discard-on-raid5.md](discard-on-raid5.md).

**A reboot is a partial reset of this host, not a clean restart of a known state.**
Anything in the top row of that table returns to whatever BCM specifies,
regardless of what is on local disk. Post-reboot verification has to check the
kernel-side settings explicitly, because the local files that describe them will
still look correct.

**`update-initramfs` output on this host is not evidence of anything.** If a
procedure's persistence argument rests on rebuilding the initramfs, the procedure
does not persist here.

The same trap caught the bring-up agent's reboot persistence, though by a
different mechanism — a systemd user manager that never started because `/home`
is NFS-mounted and `logind` came up before it was available. That one is written
up in the bring-up runbook rather than here, but the shared lesson is the same:
on this host, "I applied the change and it worked" and "the change will still be
there tomorrow" are independent claims requiring independent tests.
