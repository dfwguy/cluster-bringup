# How to install enroot for container job submission

**Goal:** install enroot on the observability node so that `srun --container-image=...` and
`sbatch --container-image=...` can launch Pyxis container jobs.

## Before starting

- Root on this node.
- Root on the head node (needed to download BCM packages — see [Downloading BCM packages](#downloading-bcm-packages) below).
- `srun` already working — see [enable-job-submission.md](enable-job-submission.md).
- `/cluster` mounted and writable — it is the staging area for the packages.

## Downloading BCM packages

BCM's package repository requires credentials. `apt-get download` works only as root on a managed
node. The pattern for any BCM package is: download as root on the head node into `/cluster/dpkg/`,
then install from there on the observability node.

On the head node as root:

```
mkdir -p /cluster/dpkg
cd /cluster/dpkg && apt-get download enroot enroot+caps
```

Check what you got:

```
ls -lh /cluster/dpkg/enroot*.deb
```

## Install on the observability node

Enroot depends on `parallel`. A plain `apt-get install -y parallel` fails on this node because the
package conflicts with a file already installed by `moreutils` (both ship a `parallel` man page).
Force the overwrite:

```
sudo apt-get -o Dpkg::Options::="--force-overwrite" install -y parallel
```

Then, on the observability node as root:

```
cd /cluster/dpkg && dpkg -i enroot*.deb
```

Passing both packages lets `dpkg` install them in dependency order.

## Reinstall and verify Enroot capabilities

`enroot+caps` installs the file capabilities that the unprivileged Enroot helper needs. Reinstall
it after the package installation, then verify that both required capabilities are present:

```console
sudo apt install --reinstall enroot+caps
getcap /usr/bin/enroot-aufs2ovlfs
```

Expected output:

```text
/usr/bin/enroot-aufs2ovlfs cap_sys_admin,cap_mknod=ep
```

If `getcap` prints no output or the capabilities differ, do not proceed with container creation;
rerun the reinstall and investigate the package installation first.

## Run the basic import validation

```
enroot version
```

You should see `4.1.2` (or whichever version was downloaded) with no permission errors.

Run the following as an unprivileged submitting user. Alpine is public, so this tests Enroot's
basic registry import without requiring an NGC key. The output image is deliberately kept out of
the checked-out repository:

```console
VALIDATION_DIR="/cluster/$USER/enroot-validation"
install -d -m 0700 "$VALIDATION_DIR"
enroot import --output "$VALIDATION_DIR/alpine.sqsh" docker://alpine
```

Successful layer extraction and SquashFS creation confirm that the Enroot importer works. This
does not test NGC authentication or Pyxis; complete the configuration guide for those checks.

Then continue with [Configure Enroot for NGC and Pyxis jobs](configure-enroot.md). That guide is
run as the submitting user and covers NGC credentials, per-user `/cluster` storage, and testing a
container job.

## Related

- [enable-job-submission.md](enable-job-submission.md) — the SPANK plugin and MPI layers this builds on.
- [mount-cm-shared.md](mount-cm-shared.md) — `/cluster` must be mounted for the staging area to exist.
- [configure-enroot.md](configure-enroot.md) — configure NGC access and run container jobs after installation.
