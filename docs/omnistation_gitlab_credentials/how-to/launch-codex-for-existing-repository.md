# How to launch Codex for an existing child repository

Use this when `~/git/nvis-ova/cluster-bringup` is already cloned. Varlock reads
configuration from the parent workspace while Codex starts with the child
repository as its working root.

## Verify both directories

```console
test -f ~/git/nvis-ova/.env.schema
test -x ~/git/nvis-ova/gitlab-askpass.sh
git -C ~/git/nvis-ova/cluster-bringup status --short --branch
```

The first two checks concern the credential workspace. The Git command must
target the child repository.

## Launch Codex

```console
cd ~/git/nvis-ova

GIT_ASKPASS="$PWD/gitlab-askpass.sh" \
GIT_TERMINAL_PROMPT=0 \
npm exec -- varlock run --path "$PWD" --inject vars -- \
codex -C "$PWD/cluster-bringup" --yolo
```

`--path "$PWD"` tells Varlock to resolve the parent workspace even though
Codex changes its working root. Codex `-C` selects the existing child
repository. It does not create a repository or change which directory owns Git
history.

The resolved token is available to Codex and its child processes. The
`--inject vars` option avoids injecting Varlock's additional serialized
environment blob, but it does not hide individual variables from Codex.

`--yolo` disables approvals and sandboxing. Run it only in a dedicated,
externally isolated environment and only after trusting the repository content.
Omit `--yolo` when that external isolation and trust boundary is absent.
