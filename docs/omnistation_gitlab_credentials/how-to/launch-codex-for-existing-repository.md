# How to launch Codex for an existing group repository

Use this when a repository in the `nvis-ova` group is already cloned and the
reusable launcher from [tutorial step 16](../tutorial.md#16-install-the-reusable-codex-launcher)
is installed. Varlock reads configuration from the credential workspace while
Codex starts with the selected repository as its working root.

## Verify both directories

```console
test -f ~/git/nvis-ova/.env.schema
test -x ~/git/nvis-ova/gitlab-askpass.sh
test -x ~/git/nvis-ova/codex-varlock-yolo.sh
project_path="<project-path>"
project_dir="$HOME/git/nvis-ova/$project_path"
git -C "$project_dir" status --short --branch
```

The first three checks concern the credential workspace. Replace
`<project-path>` with a project path relative to `nvis-ova`, such as
`cluster-bringup` or `some-subgroup/some-project`.

## Start or resume Codex

Start a new session rooted in the selected repository:

```console
~/git/nvis-ova/codex-varlock-yolo.sh \
  -C "$project_dir"
```

Resume the most recent session associated with that repository:

```console
~/git/nvis-ova/codex-varlock-yolo.sh \
  -C "$project_dir" \
  resume --last
```

The launcher changes to the credential workspace, resolves Varlock there,
configures askpass, and then forwards the shown arguments to Codex. Codex `-C`
selects the repository. Point `project_dir` at any clone the group token is
permitted to access; the launcher is not tied to `cluster-bringup`.

The resolved token is available to Codex and its child processes. The
`--inject vars` option avoids injecting Varlock's additional serialized
environment blob, but it does not hide individual variables from Codex.

The launcher always enables YOLO mode, which disables approvals and sandboxing.
Run it only in a dedicated, externally isolated environment and only after
trusting the repository content. Use Codex directly without the launcher when
that external isolation and trust boundary is absent.
