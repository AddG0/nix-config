Nix conventions:
- Flakes only — no `nix-env`, `nix-channel`, or `nix-shell`
- For ad-hoc tooling, use `nix shell` or `nix run`
- Minimal function signatures — only params actually used
