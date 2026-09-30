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

Only tag things the _pin_ causes. A workaround for a permanent upstream design
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
`CHECK-FLAKE-ATTR:` / `CHECK-CUSTOM-ATTR:` / `CHECK-RUNTIME:` lines it expects.
Packages from a flake input need the second — plain nixpkgs has a different
package under that name, or none.

### Our own packages

Our packages live in `pkgs/by-name/`: add `<name>/package.nix` (or `<name>.nix`);
a directory without one nests. They're one attr, `pkgs.addg`, so a workaround
patches the scope, one `overrideScope` per level:

```nix
addg = prev.addg.overrideScope (_: aprev: {
  decky = aprev.decky.overrideScope (_: dprev: { … });
});
```

Mark it `CHECK-CUSTOM-ATTR:` so `check-workarounds` builds the package without
our workarounds. Modules get the scope as `customPkgs` and our lib as
`customLib`, the same values as `pkgs.addg` and `lib.custom`. Why: ADR 0002.

## Optional modules and suites

Import optional modules through `lib.custom.optional.{hosts,home,primary}`. A
`.nix` file or a directory with `default.nix` is a module, any other directory
just groups them, and `_` hides a file. `just optional` lists everything.

A suite is a set of modules taken together, declared in `_suites.nix` in the
folder holding them; anything there it doesn't list is an add-on. Hosts import a
suite with `lib.custom.useSuite`, which brings its home half along.

Order imports external, then host-local, then ours: suites, the root block, then
one `with` block per namespace.

```nix
imports = lib.flatten [
  inputs.hardware.nixosModules.common-pc-ssd
  ./hardware-configuration.nix
  (lib.custom.useSuite lib.custom.suites.gaming)
  (with lib.custom.optional.hosts; [nix-cache])
  (with lib.custom.optional.hosts.nixos.services; [openssh tailscale])
];
```

Home trees split by domain (`desktops/`, `services/`), never by platform; a
platform-bound home module says so with `lib.hm.assertions.assertPlatform`. Only
`hosts/common/optional` has `nixos/` and `darwin/`, because those are different
module systems. Why: ADR 0001.
