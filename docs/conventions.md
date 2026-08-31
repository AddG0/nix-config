# Repository Conventions

## `FLAKE-UPDATE:` markers

Sometimes a bit of config exists only to work around a bug in whatever version a
flake input happens to be pinned at right now. Once that input gets bumped the
workaround is dead weight — but there's nothing to remind you, so it quietly
lives forever.

Tag those spots with a `# FLAKE-UPDATE:` comment (think `# TODO:`, but for
"delete me after the next bump"). Say what to remove and what has to be true
upstream before it's safe:

```nix
permittedInsecurePackages = [
  # FLAKE-UPDATE: drop once legcord bumps off this pnpm. legcord 1.2.4 pins
  # pnpm-10.29.2 (build-only, not in runtime closure) which carries
  # CVE-2026-48995 + 6 others.
  "pnpm-10.29.2"
];
```

Only tag things the *pin* causes. A workaround for a permanent upstream design
choice isn't going away on a bump, so a marker there is just noise.

### Checking them

`just update` prints every marker after the inputs land, so the list is in front
of you at the moment it matters. Outside of an update, `just check-markers`
prints the same thing on demand.

Walk the list and delete whatever the bump fixed. Nothing is automatic — the
marker tells you where to look and what to look for, you still confirm it.

### Workarounds that patch a package

If the workaround is a package override rather than a line of config, it belongs
in `overlays/flake-update-workarounds/` instead. Those get a stronger check:
`just check-workarounds` builds each one against plain upstream nixpkgs and tells
you which now build fine on their own — no judgement call needed. See the header
of `scripts/check-flake-workarounds.sh` for the `CHECK-ATTR:` /
`CHECK-FLAKE-ATTR:` / `CHECK-RUNTIME:` lines it expects. Packages from a flake
input need the second — plain nixpkgs has a different package under that name,
or none.
