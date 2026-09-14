# effect's zsh completion generator gives a command's own positional args the
# slot 1 it then assigns to the subcommand, so `t3 <TAB>` dies on "doubled
# argument definition" and no completion loads at all. t3's positional carries no
# completion action, so dropping it loses nothing. Patched in the installed dist,
# not the source: effect stays external to bin.mjs and postInstall generates the
# scripts by running it.
#
# postBuild of `unwrapped`, not the join: see README.md.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  completionSlotAnchor = builtins.concatStringsSep "\n" [
    "    for (const arg of descriptor.arguments) {"
    "      lines.push(`    \${argSpec(arg)}`);"
    "    }"
    "    lines.push(`    '1:command:->command'`);"
  ];
  completionSlotPatch = "    lines.push(`    '1:command:->command'`);";
in {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postBuild =
        (old.postBuild or "")
        + ''
          substituteInPlace node_modules/.pnpm/effect@*/node_modules/effect/dist/unstable/cli/internal/completions/zsh.js \
            --replace-fail ${escapeShellArg completionSlotAnchor} ${escapeShellArg completionSlotPatch}
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
