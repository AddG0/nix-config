---
status: accepted
date: 2026-11-06
---

# Inside a git repo, git config picks a Claude session's pool; outside one, folder routes do

Supersedes in part the earlier rule that routed each Claude Code session by its
directory alone. Each pool's host, and the client never falling back between
hosts, stand.

## Context and Problem Statement

`ai-proxy ready claude` picks the pool, personal or work, whose host a Claude
Code session uses. Until now the session's directory picked it:
`ai-proxy.claude.routes` sent the work root to work and everything else to
personal, so a work clone outside the work root went to personal. An
`ai-proxy.claude.origins` option patched that with about 40 lines of shell
that parsed the host out of the repo's `origin` URL.

The work git identity had the same gap. A `gitdir:` include on the work root
applied it, so a work clone elsewhere committed with the personal name, email
and signing key. Two rules, in two languages, answered one question: is this a
work repo?

## Considered Options

1. Inside a git repo, `git config --get ai-proxy.pool` names the pool, set by
   the same conditional includes that apply the work identity: one `gitdir:`
   include per work root, one `hasconfig:remote.*.url:` include per spelling
   of a work remote. Outside any repo, folder routes decide.
2. Keep the `origins` option: parse the origin's host in shell, beside the
   folder routes.
3. Folder routes alone.
4. Route by the domain of the effective `user.email`.

## Decision Outcome

Chosen: option 1.

- `hasconfig:remote.*.url:` (git 2.36+) matches a remote URL as stored, before
  `insteadOf` rewrites it, so each spelling has its own include. Every
  project behind the work ssh alias is work, in scp and `ssh://` form, with or
  without a port. On gitlab.com, which also hosts personal projects,
  only the work group is: scp, `ssh://` with or without port 22, and
  `https://` with or without a user. A glob crosses `/` only through `/**`.
- "Inside a repo" is wherever git finds one: a work tree, its `.git` folder,
  or a bare repo. There an unset `ai-proxy.pool` means personal, even under a
  work folder route, and `ai-proxy status` shows the origin URL, so a work
  remote no include matches is visible.
- An empty or unknown `ai-proxy.pool`, a git config git cannot read, a
  malformed routes file, or a route to something that is not a pool is a
  broken config. `ready` and `attributes` exit 2 for it, naming the key or
  file, the value and the repo, and the claude wrapper aborts the session
  rather than starting it on the profile's own login; exit 1 still only means
  the proxy is not ready.
- Outside a repo, the deepest folder route decides, so a session started at
  the bare work root stays on work.
- `ai-proxy status` names the rule that chose: git config, a folder route, or
  the default.
- Option 2 rejected: shell re-derived what git already resolves, read only
  `origin`, and left the commit identity's gap open.
- Option 3 rejected: it misses every work clone outside the work root.
- Option 4 rejected: it ties routing to an identity value rather than a key
  whose one job is routing.

### Consequences

- Good: a work clone anywhere commits with the work identity and key, and its
  sessions use the work pool. The allowed-signers file is global, so those
  commits still verify.
- Good: the work roots and remote spellings are data in one place, in
  nix-secrets, generating the `insteadOf` rewrite, the includes and the folder
  routes, so they cannot drift.
- Bad: each session start runs a few git commands in its directory.
- Bad: a work-group remote on gitlab.com spelled any other way (another
  letter case, an unlisted port) is not recognised until its spelling is
  added; `status` shows such a repo's origin.
- Bad: a typo in `ai-proxy.pool` stops Claude Code from starting in that repo
  until it is fixed.
