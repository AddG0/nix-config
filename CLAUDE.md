# nix-config conventions

## home-manager activation scripts

Use the `run` shell function, not `$DRY_RUN_CMD` (deprecated since
home-manager 24.05).

```nix
home.activation.example = lib.hm.dag.entryAfter ["writeBoundary"] ''
  run mkdir -p "$HOME/.config/foo"
  run touch "$HOME/.config/foo/bar"
'';
```

`run` respects `home-manager switch --dry-run` automatically — it echoes the
command in dry-run mode and executes it otherwise. Same applies to other
`$DRY_RUN_*` and `$VERBOSE_*` variables: prefer the `run` / `verboseEcho`
shell helpers home-manager exposes inside activation scripts.

Source: [home-manager release notes (24.05)](https://nix-community.github.io/home-manager/release-notes.xhtml).
