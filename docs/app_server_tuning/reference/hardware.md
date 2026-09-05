# Hardware

Verified on `appserver-nc`, 2026-08-27. Neutral facts; the consequences are in
[the-gen4-ceiling.md](../explanation/the-gen4-ceiling.md).

## Chassis and OS

| Property | Value |
|---|---|
| Chassis | Dell PowerEdge R760 |
| OS | Ubuntu 24.04.4 LTS |
| Kernel | 6.8.0-106-generic |
| Boot | PXE — kernel and initramfs served by the BCM head node |
| Root filesystem | local, persistent |
| Roles | Slurm controller (`slurmctld`), NFS server for `/cluster`, application host |

Because the kernel and initramfs come from BCM, locally rebuilt initramfs images
and GRUB configuration are never read. See
[pxe-boot-and-local-config.md](../explanation/pxe-boot-and-local-config.md).

## CPU

| Property | Value |
|---|---|
| Model | 2 × Intel Xeon Gold 6430 |
| Family / model | 6 / 143 (Sapphire Rapids) |
| Cores / threads | 64 cores, 128 threads |
| NUMA nodes | 2 |
| Frequency driver | `intel_cpufreq` |
| Governor | `performance` |

**CPU enumeration is interleaved**, not contiguous:

```
node0: 0,2,4,6,8,...,126     (all even)
node1: 1,3,5,7,9,...,127     (all odd)
```

Anything mapping a CPU number to a NUMA node must read
`/sys/devices/system/node/node*/cpulist`. Arithmetic that assumes contiguous
ranges — `cpu < 32`, or `cpu >= 64 && cpu < 96` — produces wrong node labels on
this host, and did so in one of our own earlier analyses.

## Memory

| Property | Value |
|---|---|
| `MemTotal` | 1056303368 kB ≈ 1007 GiB |
| Swap | none configured |

## NVMe — the `/cluster` array

Six drives, one partition each, members of `md0`.

| Property | Value |
|---|---|
| Model string | `MTFDLAL7T6THA-1BK1JABDA` |
| Product | Micron 9550 PRO, 7.68 TB |
| Rated interface | **PCIe Gen5 x4** |
| Negotiated interface | **PCIe Gen4 x4** |
| `dlfeat` | 9 — deallocated blocks read as zero, deterministically |

The Gen4 negotiation is not a downtrain or a misconfiguration. The R760's U.2
bays are Gen4-only by design; the platform's Gen5 lanes are routed to the riser
slots. No BIOS or firmware change alters this.

Link bandwidth arithmetic:

| Quantity | Value |
|---|---|
| Gen4 x4, one drive | ~7.88 GB/s = 7.34 GiB/s |
| Six drives, theoretical | 44.0 GiB/s |
| Measured sequential read | 40.3 GiB/s (92% of theoretical) |

Device names are not stable across reboots — see
[md0.md](md0.md).

## OS disk

| Property | Value |
|---|---|
| Device | Dell BOSS-N1, NVMe |
| Holds | `/`, `/boot` |

Separate from the `/cluster` array. Nothing in this documentation tunes it.

## Network

| Property | Value |
|---|---|
| NICs | Mellanox/NVIDIA ConnectX-7 |
| Ports | 6 mlx5 ports |
| PCIe | Gen5 x16 — the platform's Gen5 lanes |
| Bond | `bond0`, LACP 802.3ad |
| Bonded legs | 2 × 200 GbE = 400 Gb/s |
| MTU | 9000 on the bond; one access port at 1500 |

400 Gb/s is 50 GB/s, about 46.6 GiB/s at the wire. The array reads at 40.3 GiB/s,
so array read bandwidth and network egress are the same order of magnitude and
neither is dramatically limiting for NFS clients.

The ConnectX-7 cards negotiating Gen5 x16 is what proves the platform's root ports
are Gen5-capable, and therefore that the drives' Gen4 link is a backplane
property rather than a CPU or BIOS one.

## Filesystems

| Mount | Backing | Type | Notes |
|---|---|---|---|
| `/cluster` | `md0` | XFS | 34.93 TiB. Exported NFSv4.2 from this host. Geometry already recorded correctly in the superblock, so no `sunit`/`swidth` fstab override is needed |
| `/home` | `<home-server>` (NFS, off-host) | NFSv3 | Remote. Relevant because systemd user managers depending on it fail early in boot |
| `/` | BOSS-N1 | — | Local, persistent |
