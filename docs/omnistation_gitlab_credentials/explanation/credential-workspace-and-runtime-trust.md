# Explanation: credential workspace and runtime trust

The NVIS layout separates a group-scoped credential from every project that
uses it. That separation solves a bootstrap problem and makes the security
boundary visible, but it does not turn an injected secret into an inaccessible
one.

## Why the credential workspace comes first

A private project cannot be cloned until Git can authenticate. If Varlock were
configured only inside that project, its configuration would be unavailable at
the moment it was first needed. A user-created group workspace such as
`~/git/nvis-ova` exists before any child clone, so it can authenticate the read
that creates `cluster-bringup`.

The credential belongs to the GitLab group rather than one repository. Subject
to the token's scopes, role, and each project's policies, the same parent
workspace can support other repositories cloned beneath it. This is an NVIS
convention, not a Varlock requirement; application-specific Varlock schemas
normally belong directly in their application repositories.

## Why the parent is not a Git repository

The parent holds machine-local operating material: an encrypted token payload,
an askpass adapter, the pinned Varlock package, and perhaps several child
clones. Initializing Git there would create a second history that could
accidentally treat those children and credentials as content.

Instead, `cluster-bringup/.git/` owns the project's existing history. Git
discovers a work tree by walking from the command's working directory. A Git
command run in the parent therefore reports `not a git repository`, while the
same command run in the child uses the correct history. That location error is
independent of authentication.

Because the parent is outside the child's work tree, `.env.local`, its encrypted
payload, and `gitlab-askpass.sh` cannot enter a child commit. This structural
boundary complements, but does not replace, ignore rules and review.

## Encrypted at rest is not protected at runtime

Varlock replaces `varlock(prompt)` with a device-local encrypted value. A copied
payload is not a portable credential and must not be shared. This protects the
token while stored on disk.

To use the token, some process must receive its resolved value. `varlock run`
decrypts the value and injects it into the child process. Codex, Git's askpass
child, and other descendants can therefore access it. A compromised or
prompt-injected process with that authority can use or disclose the token.
Varlock at-rest encryption is not a runtime sandbox.

The default `varlock run` mode also injects a serialized `__VARLOCK_ENV` blob.
`--inject vars` omits that blob and passes only the individual variables. This
reduces unnecessary environment exposure, but `GITLAB_TOKEN` remains available
because Git must use it.

## Why askpass is better than a credential URL

Git knows how to request a username and password, but it assigns no special
meaning to `GITLAB_TOKEN`. `GIT_ASKPASS` bridges those interfaces at the moment
Git requests credentials.

The helper stores only literal variable references. A token embedded in a URL
can leak through shell history, logs, error messages, process inspection,
configuration, and remote listings. Askpass avoids persisting the resolved
token in those places and works with ordinary HTTPS remote URLs.

It is still a runtime delivery mechanism. The helper prints the token to Git's
credential prompt channel, so Git receives the real value.

## Why Codex YOLO mode needs external isolation

Codex `--yolo` disables both approvals and sandboxing. With an injected group
token, the agent can run commands using the token without an approval boundary.
Trusted repository content matters because checked-out instructions, scripts,
or dependencies can influence those commands.

The safe boundary must therefore exist outside Codex: a dedicated environment,
restricted network and filesystem reach, and repository content that has been
reviewed or otherwise trusted. Varlock protects storage but does not provide
that isolation.

## How the credential proxy differs

Varlock's [credential proxy](https://varlock.dev/guides/proxy/) aims to give the
child a placeholder and substitute the real secret only at a verified network
boundary. That can reduce the ease with which an agent reads or prints a raw
credential compared with environment injection.

The proxy is currently an early-preview feature. Its flags, decorators, and
behavior can change in minor releases, so any evaluation must pin the exact
Varlock version. Routing must be validated for the precise GitLab hostname,
paths, methods, redirects, proxy mode, and Git/curl client behavior. A
placeholder can also fail client-side format checks, and clients that do not
use the proxy's supported HTTP(S) path will not receive wire-time substitution.

The proxy and agent also run as the same operating-system user. The proxy does
not by itself isolate the filesystem, processes, or memory, so it raises the
bar rather than forming a hard security boundary.

For these reasons, the proxy is optional advanced hardening rather than the
stable default in this guide. Adopt it only after version-pinned compatibility
and routing tests, and pair it with external sandboxing or container isolation.

## Security boundaries in one view

| Boundary | Protects | Does not protect |
|---|---|---|
| Device-local Varlock encryption | Token stored in `.env.local` | Token after successful resolution |
| Parent/child directory separation | Project commits from parent workspace files | A runtime process allowed to read the parent |
| `--inject vars` | Avoids the serialized Varlock blob | Individual injected variables |
| `GIT_ASKPASS` | Avoids a credential-bearing URL or Git configuration | Token while Git is using it |
| GitLab scopes and role | Limits operations and resource reach | Misuse within the granted authority |
| Protected branches | Direct changes to protected refs | Permitted feature-branch pushes or MR creation |
| External isolation | Runtime filesystem, process, and network reach | Mistakes in the isolation design itself |

The [reference](../reference/varlock-gitlab-reference.md) records the exact
paths and controls; the [tutorial](../tutorial.md) applies them in order.
