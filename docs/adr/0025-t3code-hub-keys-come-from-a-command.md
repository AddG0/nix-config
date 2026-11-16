---
status: accepted
date: 2026-11-09
---

# T3 Code reads a secret from a command, uncached, so its usage hubs sign in with `ai-proxy token`

## Context and Problem Statement

T3 Code's usage hubs list each pooled login's limits by calling a CLIProxyAPI
management API with a key from T3's settings. The AI proxy now serves that
API through its gateway, which accepts only the short-lived access token that
`ai-proxy token` prints, the same one Claude Code's `apiKeyHelper` sends. T3
should hold no static secret, so the hub key has to come from that command.

A hub key is a secret setting: a literal, or a reference to a configured
secret provider that T3's resolver reads. The only built-in provider is
1Password, and the resolver keeps every value it reads, failed reads too, for
the server's life; only the Settings refresh drops them. The hub reader never
asks it to, not even on a 401, so once a cached token expired every hub
would fail until the server restarted.

T3 0.1.6, which nixpkgs builds, keeps the hub key a plain string; references
reach hub keys in 0.1.7. Its secrets settings, and the picker that points a
setting at a provider, are also compiled out unless the web build sees
`T3CODE_FEATURE_SECRETS`.

## Considered Options

1. A `command` secret provider whose definition opts out of the resolver's
   cache: a reference is a command line, split on whitespace and run without a
   shell, and its trimmed output is the value.
2. A key-command field on the hub settings alone.
3. A cache lifetime per provider.
4. Invalidating the key on a 401 in the hub reader and retrying once.

## Decision Outcome

Chosen: option 1, carried as a patch to T3's source.

- A definition gains `cacheable` (default `true`); the resolver neither stores
  nor answers from its cache for a kind that sets it `false`. The command kind
  does, so each hub refresh runs `ai-proxy token`, which answers from its own
  token file and refreshes only near expiry.
- The provider's config is an optional timeout, 10 seconds by default and at
  most 120: the resolver reads one provider at a time, so a hung command would
  hold up every other uncached read; a command that ignores SIGTERM at its
  timeout is killed a second later. A non-zero exit, a timeout, blank output
  or a program that cannot start reads as unset. The server log names the
  program, with the exit code and stderr's last line (capped at 200
  characters) or why it could not start, and the hub names the provider whose
  key it could not read.
- On Windows a `.cmd` or `.bat` program runs through `cmd.exe`, with its
  arguments escaped, as T3 runs every such program.
- Settings → Secrets offers the kind, with a timeout field, beside 1Password.
- The ai-proxy module declares the `ai-proxy` provider and a hub per instance in
  `programs.t3code.userSettings`, from the same pools and domain as its other
  clients. Home Manager merges them into T3's settings file, which T3 can still
  edit; a hub dropped from Nix stays in that file until removed in T3.
- T3 is held at 0.1.8 ahead of nixpkgs, for references in hub keys; the
  worktree-picker patch was rebased onto it.
- The web build sets `T3CODE_FEATURE_SECRETS`, so the secrets settings and the
  provider picker exist.
- Option 2 rejected: it would solve one setting where any secret setting can
  want a token helper, and it adds a hub-only code path to a reader that
  already resolves references.
- Option 3 rejected: a lifetime has to guess the token's expiry, which the
  command already tracks, and a guess too long fails the hub until it lapses.
- Option 4 rejected: it fixes the hub reader alone, where every other reader
  of a token helper would still hold an expired value, and each expiry costs
  a refused request first. Worth proposing upstream on its own, since it also
  helps a rotated literal key.

### Consequences

- Good: no static secret for the hubs in T3's settings or on disk; the token
  is the one Claude Code already uses.
- Good: any secret setting can now come from a command, such as a token
  helper for a model provider's API key.
- Bad: two patches to carry until upstream takes the provider, and the version
  hold until nixpkgs reaches 0.1.8. A bump that moves the patched code fails
  the build rather than dropping the change.
- Bad: a setting can name a program the server runs. Anyone who can change
  T3's settings can already point a provider at any binary, so this adds no
  reach, but upstream has to weigh it for remote environments.
- Upstream: the provider and `cacheable` are offered as a pull request; the
  overlay is dropped when a release ships them.
