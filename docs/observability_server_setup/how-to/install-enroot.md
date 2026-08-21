# How to install enroot for container job submission

**Goal:** install enroot on the observability node so that `srun --container-image=...` and
`sbatch --container-image=...` can launch Pyxis container jobs.

## Before starting

- Root on this node.
- Root on the head node (needed to download BCM packages — see [Downloading BCM packages](#downloading-bcm-packages) below).
- `srun` already working — see [enable-job-submission.md](enable-job-submission.md).
- `/cluster` mounted and writable — it is the staging area for the packages.
- Each user who will pull a private NGC image needs their own NGC API key. Do not share a
  key or add it to a system-wide Enroot configuration.

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

## Configure NGC access and shared Enroot data

Do this **as the submitting user** (for example, `cmods`), not as root. It is separate from
installing the packages above. Pyxis starts Enroot as the job user on the allocated compute node,
so that user's credentials and data path must be available there.

### 1. Generate a personal NGC API key

Open [NGC API Keys](https://org.ngc.nvidia.com/account/api-keys), select **Generate Personal Key**,
give it a descriptive name such as `cluster-enroot-cmods`, choose the shortest practical expiration,
and include the NGC Catalog service. Copy the key when it is displayed: NGC does not show it again.

Personal keys are appropriate for a person using the cluster. For a non-interactive shared service,
have the NGC organization administrator create a service key instead. Its access and rotation must
be managed as a service credential.

### 2. Save the key in Enroot's credential file

Create the user-only configuration directory and open the credentials file in an editor:

```console
install -d -m 0700 "$HOME/.config/enroot"
umask 077
${EDITOR:-vi} "$HOME/.config/enroot/.credentials"
```

Add both NGC endpoints below, replacing `<NGC_API_KEY>` in each line with the key. Keep
`$oauthtoken` literal; it is NGC's API-key username. Enroot documents both endpoint entries as
required for NGC registry authentication.

```text
machine nvcr.io login $oauthtoken password <NGC_API_KEY>
machine authn.nvidia.com login $oauthtoken password <NGC_API_KEY>
```

Then restrict the file and confirm only the owner can read it:

```console
chmod 0600 "$HOME/.config/enroot/.credentials"
stat -c '%a %U:%G %n' "$HOME/.config/enroot/.credentials"
```

Expected mode is `600`. Never put the key in a command line, shell profile, Slurm script, Git
repository, or shared `/cluster` directory. Rotate or revoke the key in NGC immediately if it is
exposed.

### 3. Put Enroot's data in a per-user `/cluster` directory

Give every cluster user their own Enroot tree. Use the POSIX login name in `$USER` (not a
group-writable shared directory):

```console
export ENROOT_DATA_PATH="/cluster/$USER/.local/share/enroot/data"
install -d -m 0700 "$ENROOT_DATA_PATH"
```

The path must be writable by the job user and mounted at the same path on every compute node that
can run the job. Check that before attempting a pull:

```console
test -w "$ENROOT_DATA_PATH" && srun -N1 --time=1 --export=ALL,ENROOT_DATA_PATH \
    sh -c 'test -w "$ENROOT_DATA_PATH" && printf "%s\\n" "$ENROOT_DATA_PATH"'
```

Persist the setting for future login shells:

```console
printf '%s\n' 'export ENROOT_DATA_PATH="/cluster/$USER/.local/share/enroot/data"' \
    >> "$HOME/.profile"
```

For jobs submitted by a non-login shell or automation, explicitly export it with the job, as shown
in the verification command below. Do not make a shared Enroot data directory group-writable with
`chown cmods:cmods` and `chmod g+w`: that lets peers alter each other's container state. The
per-user directory is created owner-only (`0700`) instead.

### Troubleshoot `mkdir: cannot create directory '/run/enroot'`

For example, this failure from `enroot create`:

```console
enroot create --name testimg /cluster/containers/image.sqsh
mkdir: cannot create directory '/run/enroot': Permission denied
```

means Enroot's runtime path resolves to the root-owned `/run/enroot`. `ENROOT_DATA_PATH` is not
the cause: it stores persistent container data, while `ENROOT_RUNTIME_PATH` holds Enroot's runtime
state. Point it at the user-writable cluster location instead:

```console
export ENROOT_RUNTIME_PATH="/cluster/$USER/.local/share/enroot/runtime"
install -d -m 0700 "$ENROOT_RUNTIME_PATH"
enroot create --name testimg /cluster/containers/image.sqsh
```

Persist the setting for interactive Bash sessions and login shells:

```console
printf '%s\n' 'export ENROOT_RUNTIME_PATH="/cluster/$USER/.local/share/enroot/runtime"' \
    >> "$HOME/.bashrc"
printf '%s\n' 'export ENROOT_RUNTIME_PATH="/cluster/$USER/.local/share/enroot/runtime"' \
    >> "$HOME/.profile"
```

The runtime directory must be writable by the job user and visible at the same path on every node
that can run the job. Export the same value to the Slurm job.

## Verify an authenticated container job

```
enroot version
```

You should see `4.1.2` (or whichever version was downloaded) with no permission errors.

Pull a small NGC image through Pyxis. NGC image syntax uses `#` between the registry and image
name, rather than Docker's `/` syntax:

```console
srun -N1 --time=3 --export=ALL,ENROOT_DATA_PATH,ENROOT_RUNTIME_PATH \
    --container-image=nvcr.io#nvidia/cuda:12.9.1-base-ubuntu24.04 \
    bash -c 'cat /etc/os-release | head -3'
```

A result printed inside the CUDA container means Enroot, the NGC credentials, the shared data
path, and Pyxis are cooperating correctly. The first run downloads and converts the image, so it
can take several minutes; later runs should reuse the local Enroot data.

If the command returns `401 Unauthorized` or `denied`, confirm that the key is active and includes
NGC Catalog access, that both machine entries are present, and that the credential file is owned by
the submitting user with mode `0600`. If it reports a missing path or permission error, rerun the
shared-path check and verify `/cluster` is mounted on the allocated node.

Record the downloaded Enroot version and revalidate container submission after
cluster upgrades.

## Related

- [enable-job-submission.md](enable-job-submission.md) — the SPANK plugin and MPI layers this builds on.
- [mount-cm-shared.md](mount-cm-shared.md) — `/cluster` must be mounted for the staging area to exist.
- [Enroot import documentation](https://github.com/NVIDIA/enroot/blob/main/doc/cmd/import.md) — registry credential format and image-import syntax.
- [NGC Catalog user guide](https://docs.nvidia.com/ngc/latest/ngc-catalog-user-guide.html) — API-key creation, rotation, and service-key guidance.
