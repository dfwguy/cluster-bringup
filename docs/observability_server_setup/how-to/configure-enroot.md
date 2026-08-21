# How to configure Enroot for NGC and Pyxis jobs

**Goal:** configure a submitting user's NGC credentials and per-user Enroot storage so that
`srun --container-image=...` and `sbatch --container-image=...` can launch Pyxis container jobs.

## Before starting

- Enroot is installed — see [Install Enroot](install-enroot.md).
- `srun` already works — see [enable-job-submission.md](enable-job-submission.md).
- `/cluster` is mounted on the submission host and every compute node that can run the job.
- Do this as the submitting user (for example, `cmods`), not as root.

Pyxis starts Enroot as the job user on the allocated compute node, so each user's credentials and
paths must be accessible there.

## 1. Create an NGC API key

Open [NGC API Keys](https://org.ngc.nvidia.com/account/api-keys), select **Generate Personal Key**,
give it a descriptive name such as `cluster-enroot-cmods`, choose the shortest practical expiration,
and include the NGC Catalog service. Copy the key when it is displayed: NGC does not show it again.

Personal keys are for an individual user. For a non-interactive shared service, have the NGC
organization administrator create and manage a service key instead.

## 2. Configure NGC credentials

Create the user-only configuration directory and open the credentials file:

```console
install -d -m 0700 "$HOME/.config/enroot"
umask 077
${EDITOR:-vi} "$HOME/.config/enroot/.credentials"
```

Add both NGC endpoints below, replacing `<NGC_API_KEY>` in each line with the key. Keep
`$oauthtoken` literal; it is NGC's API-key username.

```text
machine nvcr.io login $oauthtoken password <NGC_API_KEY>
machine authn.nvidia.com login $oauthtoken password <NGC_API_KEY>
```

Restrict the file and check its mode:

```console
chmod 0600 "$HOME/.config/enroot/.credentials"
stat -c '%a %U:%G %n' "$HOME/.config/enroot/.credentials"
```

The expected mode is `600`. Never put the key in a command line, shell profile, Slurm script, Git
repository, or shared `/cluster` directory. Rotate or revoke the key in NGC immediately if exposed.

## 3. Configure per-user Enroot paths

Give every user a separate Enroot tree under `/cluster`; do not use a group-writable shared
directory. Run this once in the submitting shell:

```console
export ENROOT_DATA_PATH="/cluster/$USER/.local/share/enroot/data"
export ENROOT_RUNTIME_PATH="/cluster/$USER/.local/share/enroot/runtime"
install -d -m 0700 "$ENROOT_DATA_PATH" "$ENROOT_RUNTIME_PATH"
```

Persist both exports in `.bashrc` and `.profile`. `.bashrc` is used by interactive non-login Bash
shells; `.profile` is used by login shells:

```console
printf '%s\n' 'export ENROOT_DATA_PATH="/cluster/$USER/.local/share/enroot/data"' \
    'export ENROOT_RUNTIME_PATH="/cluster/$USER/.local/share/enroot/runtime"' >> "$HOME/.bashrc"
printf '%s\n' 'export ENROOT_DATA_PATH="/cluster/$USER/.local/share/enroot/data"' \
    'export ENROOT_RUNTIME_PATH="/cluster/$USER/.local/share/enroot/runtime"' >> "$HOME/.profile"
```

`ENROOT_DATA_PATH` stores persistent container data; `ENROOT_RUNTIME_PATH` stores Enroot runtime
state. If `enroot create` reports `mkdir: cannot create directory '/run/enroot': Permission denied`,
the runtime export above is missing from the shell that ran the command. Do not fix this by making
`/run/enroot` writable.

Confirm that the data path is writable both locally and on an allocated compute node:

```console
test -w "$ENROOT_DATA_PATH" && srun -N1 --time=1 \
    --export=ALL,ENROOT_DATA_PATH,ENROOT_RUNTIME_PATH \
    sh -c 'test -w "$ENROOT_DATA_PATH" && test -w "$ENROOT_RUNTIME_PATH"'
```

For jobs submitted by automation or a non-login shell, explicitly export both variables as shown.

## 4. Repair and validate Enroot when needed

An existing Enroot installation can lose the file capabilities required by its unprivileged helper.
If `enroot create` or container setup fails, have an administrator reinstall `enroot+caps` on the
observability node, then verify the helper's capabilities:

```console
sudo apt install --reinstall enroot+caps
getcap /usr/bin/enroot-aufs2ovlfs
```

Expected output:

```text
/usr/bin/enroot-aufs2ovlfs cap_sys_admin,cap_mknod=ep
```

After the paths in step 3 are configured, run this as the submitting user to validate the public
registry importer. It does not require an NGC key and keeps the test image in the user's `/cluster`
directory:

```console
VALIDATION_DIR="/cluster/$USER/enroot-validation"
install -d -m 0700 "$VALIDATION_DIR"
enroot import --output "$VALIDATION_DIR/alpine.sqsh" docker://alpine
```

Successful layer extraction and SquashFS creation confirm that Enroot's basic importer works. If
the capability check is empty or different, repair that before continuing with container creation.

## 5. Choose one image action

### Create a container from an existing `.sqsh` image

Use this only when the image already exists. List available images first, then replace
`<actual-image>` with a displayed filename. `No such file or directory` means the image path is
wrong or absent; it is unrelated to the Enroot runtime path.

```console
find /cluster/containers -maxdepth 1 -type f -name '*.sqsh' -ls
```

```console
enroot create --name testimg /cluster/containers/<actual-image>.sqsh
```

### Download an NGC image, then create it

Use this when no suitable `.sqsh` exists. The credentials from step 2 are required.

```console
IMAGE_DIR="/cluster/$USER/containers"
install -d -m 0700 "$IMAGE_DIR"
enroot import --output "$IMAGE_DIR/cuda.sqsh" \
    docker://nvcr.io#nvidia/cuda:12.9.1-base-ubuntu24.04
enroot create --name cuda "$IMAGE_DIR/cuda.sqsh"
```

## 6. Verify an authenticated container job

NGC image syntax uses `#` between the registry and image name, rather than Docker's `/` syntax:

```console
srun -N1 --time=3 --export=ALL,ENROOT_DATA_PATH,ENROOT_RUNTIME_PATH \
    --container-image=nvcr.io#nvidia/cuda:12.9.1-base-ubuntu24.04 \
    bash -c 'cat /etc/os-release | head -3'
```

Output from inside the CUDA container confirms that Enroot, NGC credentials, `/cluster` storage,
and Pyxis work together. The first run downloads and converts the image, so it can take several
minutes. If the command returns `401 Unauthorized` or `denied`, confirm that the key is active,
includes NGC Catalog access, and is stored in the mode-`600` credential file.

## Related

- [install-enroot.md](install-enroot.md) — install the Enroot packages first.
- [enable-job-submission.md](enable-job-submission.md) — the Pyxis SPANK plugin and MPI layers.
- [mount-cm-shared.md](mount-cm-shared.md) — mount `/cluster` before using shared storage.
- [Enroot import documentation](https://github.com/NVIDIA/enroot/blob/main/doc/cmd/import.md) — registry credential format and image-import syntax.
- [NGC Catalog user guide](https://docs.nvidia.com/ngc/latest/ngc-catalog-user-guide.html) — API-key creation and service-key guidance.
