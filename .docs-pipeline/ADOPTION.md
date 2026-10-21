# Documentation pipeline adoption record

Integrated on 2026-10-20 on `feat/documentation-pipeline`. No push or deployment
was performed. The branch already existed and the working tree was clean before
adoption.

## Upstream source and review

- Repository: <https://gitlab-master.nvidia.com/nvis-ova/documentation-pipeline.git>
- Template and shared CI branch: `feat/copier-docs-pipeline`
- Inspected template commit: `89deb4ab5ad65b7697481d619d4acbcf34ffa67e`
- Copier entry point: root `copier.yml`, with `_subdirectory: template`
- Shared CI include: `/ci/docs.gitlab-ci.yml`
- Runtime entry point: `runtime/build.py`
- Adoption instructions: `docs/tutorials/adopt.md`, `docs/how-to/update.md`,
  `docs/reference/configuration.md`, and `docs/reference/validation.md` at that commit

The source was freshly cloned from the remote development branch into a temporary
directory. The onboarding package was installed in an external temporary virtual
environment. No pre-existing local documentation-pipeline checkout was used.
Copier itself fetched the remote URL with the explicit development branch.
Saved answers retain the remote URL and full resolved commit for future updates.
The CI include and runtime fetch deliberately use the requested moving branch;
future CI runs can therefore use a newer upstream commit than this recorded build.

The following command was run first with `--dry-run`, and its JSON findings and
unified diffs were inspected before the same command was run without `--dry-run`:

```bash
docs-onboard /home/micheller/cluster-bringup \
  --template https://gitlab-master.nvidia.com/nvis-ova/documentation-pipeline.git \
  --vcs-ref feat/copier-docs-pipeline \
  --ci-ref feat/copier-docs-pipeline \
  --title 'Cluster Bringup' --source-dir . \
  --dry-run --report /tmp/cluster-bringup-docs-plan.json
```

The dry run discovered 83 Markdown documents and proposed six paths:
`.copier-docs-answers.yml`, `.docs-pipeline/config.toml`, `.docs-pipeline/ci.yml`,
`.docs-pipeline/navigation.rst`, `.gitlab-ci.yml`, and `.gitignore`.
It flagged unsupported code-fence languages and directory links without landing
pages. These were reviewed and handled as described below.

## cluster-bringup changes

- Use the isolated repo_docs configuration supplied by the shared runtime; no
  consumer `repo.toml` or local copy of the build tooling is necessary.
  Source directory `.` includes the root README, `docs/`, and linked scripts.
- Add a Markdown home at `docs/index.md`, link it from the root README, and
  provide a website landing page and sidebar in `.docs-pipeline/navigation.rst`.
  Existing guide directories and tutorial/how-to/reference/explanation divisions
  remain in place. Every document is included in navigation.
- Preserve the existing `verify` job and stages. Add the `docs:pipeline` trigger
  with dependent child-pipeline status. The child includes upstream `docs:build`
  and `pages`; both explicitly select `perflab` and `size/medium` runners.
  Branch/MR pipelines build artifacts; Pages runs only on the default branch.
- Add the missing observability `how-to/README.md` landing page and repair two
  obsolete troubleshooting anchors to the current PMIx and Slurm group headings.
- Use `text` fences for PAM and Caddy configuration. Replace the Mermaid diagram
  with a readable text diagram retaining the identity, artifact-distribution,
  SSH-forwarding, and loopback HTTP paths. These choices work directly in GitLab
  and with the pinned Sphinx renderer, without disabling warnings.
- Keep the full documentation index, existing tables, commands, and relative
  document/script links. Sphinx packages both linked shell scripts as downloads.

## Validation

The unmodified upstream runtime at the recorded commit built this working tree:

```bash
python3 /tmp/cluster-bringup-docs-template/runtime/build.py /home/micheller/cluster-bringup
python3 -m http.server 8765 --bind 127.0.0.1 --directory .docs-build/site
```

For another machine, first clone the remote development branch into any temporary
directory and run its `runtime/build.py` with the consumer root as the argument.
No generated configuration refers to the temporary checkout above. The build uses
upstream's pinned repo_docs 0.39.2, repo_man 1.86.0, and Sphinx 4.5.0 package.

- Strict repo_docs/Sphinx build succeeded, including Markdown, tables, fences,
  directory links, and anchors. Build output: `.docs-build/site/index.html`.
- Crawled all 89 generated HTML files and checked 10,784 local link/asset targets,
  including fragments: no missing files or anchors.
- Confirmed both generated script downloads are byte-identical to repository files.
- Inspected desktop Chromium screenshots of the home, guide overview, measurement
  tables, configuration code, and architecture diagram, plus a mobile home view.
  Browser navigation and rendering worked; see the shared-tool defect below for
  the background version metadata request.
- `bash -n scripts/*.sh`, `shellcheck scripts/*.sh`, the existing Perl Markdown
  link checker over `README.md` and `docs/`, and `git diff --check` passed.
- Parsed parent, child, and shared CI YAML. Asserted the original verification job
  and stages are unchanged, child runner tags match the verification runner tags,
  include/runtime refs match, and Pages is default-branch-only.
- Authenticated GitLab repository-files API resolved `ci/docs.gitlab-ci.yml` at
  `feat/copier-docs-pipeline` to the recorded commit. Its contents matched the
  inspected shared file (blob `1423e974fb57cd1faf8a76b55576e272dd080449`).

## Reusable tooling defects and limitations

These belong to documentation-pipeline or its pinned renderer, separately from
this consumer integration. No upstream changes or issue submissions were made.

1. **Version metadata request returns 404.** Although the runtime sets
   `version_selector_enabled = false`, generated `_static/version.js` still fetches
   `../versions.json` relative to the site root on every inspected page. The
   runtime exports only the `latest/` contents and supplies no sibling metadata.
   Serve `.docs-build/site` and open any page in Chromium to reproduce. The
   request fails with HTTP 404; content and navigation remain usable. The shared
   runtime should disable that script or publish a coherent metadata/site layout,
   including support for project Pages subpaths. This was left visible rather
   than patched in generated output that the next CI build would replace.
2. **Known fence support limitation.** The pinned renderer has no `pam`,
   `caddyfile`, or `mermaid` lexer/rendering support; the strict build rejects them.
   Onboarding reports these cases. Plain-text consumer representations are used
   here; richer language/diagram support belongs in the shared runtime.
3. **Stale upstream adoption status.** Upstream README/validation prose says the
   development ref has not been published, but Git and the repository-files API
   now resolve it. The remote command example is usable; status prose needs an
   upstream update. No tagged release was assumed.

## Checks requiring GitLab access or an authorized pipeline run

The current credential could read the shared CI file, but consumer project,
runner-list, and project-scoped CI Lint API calls returned HTTP 403. Lint against
the shared project also returned HTTP 403. These checks remain unverified:

- GitLab's full CI expansion/lint, custom CI entry-point setting, child-pipeline
  scheduling, and Pages support from child pipelines on this GitLab instance.
- Availability of a Linux container-capable runner matching **both** configured
  tags, and its outbound access to GitLab, Ubuntu mirrors, NVIDIA Packman and
  bootstrap services, and Python package services. Local package resolution/build
  succeeded; this does not establish runner network/package access or cold-cache
  availability of every package.
- Pipeline-user read permission and the shared project's inbound `CI_JOB_TOKEN`
  allowlist for `nvis-ova/cluster-bringup` (or the containing group). The local
  credential's read access does not establish job-token access.
- Pages enabled status, URL/path configuration, and access controls appropriate
  for internal documentation. No Pages settings were changed or deployment run.
