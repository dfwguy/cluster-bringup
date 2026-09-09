# How to launch Codex for an existing child repository

Use this when `~/git/nvis-ova/cluster-bringup` is already cloned and the
reusable launcher from [tutorial step 16](../tutorial.md#16-install-the-reusable-codex-launcher)
is installed. Varlock reads configuration from the parent workspace while
Codex starts with the child repository as its working root.

## Verify both directories

```console
test -f ~/git/nvis-ova/.env.schema
test -x ~/git/nvis-ova/gitlab-askpass.sh
test -x ~/git/nvis-ova/codex-varlock-yolo.sh
git -C ~/git/nvis-ova/cluster-bringup status --short --branch
```

The first two checks concern the credential workspace. The Git command must
target the child repository.

## Start or resume Codex

Start a new session rooted in the child repository:

```console
~/git/nvis-ova/codex-varlock-yolo.sh \
  -C ~/git/nvis-ova/cluster-bringup
```

Resume the most recent session associated with that child repository:

```console
~/git/nvis-ova/codex-varlock-yolo.sh \
  -C ~/git/nvis-ova/cluster-bringup \
  resume --last
```

The launcher changes to the parent workspace, resolves Varlock there, configures
askpass, and then forwards the shown arguments to Codex. Codex `-C` selects the
existing child repository. It does not create a repository or change which
directory owns Git history.

The resolved token is available to Codex and its child processes. The
`--inject vars` option avoids injecting Varlock's additional serialized
environment blob, but it does not hide individual variables from Codex.

The launcher always enables YOLO mode, which disables approvals and sandboxing.
Run it only in a dedicated, externally isolated environment and only after
trusting the repository content. Use Codex directly without the launcher when
that external isolation and trust boundary is absent.
