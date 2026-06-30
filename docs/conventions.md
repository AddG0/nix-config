# Repository Conventions

## `FLAKE-UPDATE:` markers

Workarounds that exist only because of the **current** pinned flake inputs should
be tagged with a `# FLAKE-UPDATE:` comment (analogous to `# TODO:`), stating what
to remove and why.

```nix
permittedInsecurePackages = [
  # FLAKE-UPDATE: drop once legcord bumps off this pnpm. legcord 1.2.4 pins
  # pnpm-10.29.2 (build-only, not in runtime closure) which carries
  # CVE-2026-48995 + 6 others. Re-check after `nix flake update`.
  "pnpm-10.29.2"
];
```

After each `nix flake update`, grep with `rg -n 'FLAKE-UPDATE:'` and delete any
workaround whose cause the bump resolved.
