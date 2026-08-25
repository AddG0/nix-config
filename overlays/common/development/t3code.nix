# Source patches, applied in `unwrapped`: stdenv skips fixupPhase when
# `buildCommand` is set, so postFixup on the `t3code` symlinkJoin is a silent
# no-op, and the built bin.mjs has null bytes substituteInPlace refuses. The
# join bakes its postBuild into that buildCommand too, so overrideAttrs reaches
# neither phase.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  # The app forks its own backend instead of attaching to a running one, so it
  # needs a port of its own; 3773 stays with the server unit (home
  # .../development/ai/t3code/server.nix).
  desktopPort = 3774;

  # t3code shows an "update available" banner when a provider CLI (codex,
  # claude-code, opencode) is behind the latest npm release. We pin those CLIs
  # by path (home .../development/ai/t3code), so the banner is noise with no
  # actionable update and t3code has no setting to hide it. Forcing packageName
  # to null skips the npm version fetch, so the advisory stays "unknown" and the
  # banner never renders. Drop once t3code gains a toggle.
  versionFetchAnchor = "const packageName = maintenanceCapabilities.packageName;";
  versionFetchPatch = "const packageName = null;";

  # Worktrees land beside the clone as <clone>--<branch> instead of under
  # ~/.t3/worktrees, so gwq and `ghq list` see them like gwadd's. The anchor
  # carries real indentation: '' blocks strip the common indent and stop matching.
  worktreePathAnchor = "    const repoName = path.basename(input.cwd);\n    const worktreePath = input.path ?? path.join(worktreesDir, repoName, sanitizedBranch);";

  # gitCommonDir-to-worktree and the GitCommandError handling both mirror
  # upstream's defaultBranchCache. The cwd fallback keeps a resolution failure
  # from failing thread creation, which soft-deletes it and strands its id.
  worktreePathPatch = builtins.concatStringsSep "\n" [
    "    const repositoryPaths = yield* resolveRepositoryPaths(input.cwd).pipe("
    "      Effect.catchTags({ GitCommandError: () => Effect.succeed(null) }),"
    "    );"
    "    const primaryWorktree ="
    "      repositoryPaths && path.basename(repositoryPaths.gitCommonDir) === \".git\""
    "        ? path.dirname(repositoryPaths.gitCommonDir)"
    "        : input.cwd;"
    "    const worktreePath = input.path ?? `\${primaryWorktree}--\${sanitizedBranch}`;"
  ];

  # effect's zsh completion generator gives a command's own positional args the
  # slot 1 it then assigns to the subcommand, so `t3 <TAB>` dies on "doubled
  # argument definition" and no completion loads at all. t3's positional carries
  # no completion action, so dropping it loses nothing. Patched in the installed
  # dist, not the source: effect stays external to bin.mjs and postInstall
  # generates the scripts by running it.
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
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace apps/server/src/provider/providerMaintenance.ts \
            --replace-fail ${escapeShellArg versionFetchAnchor} ${escapeShellArg versionFetchPatch}

          substituteInPlace apps/server/src/vcs/GitVcsDriverCore.ts \
            --replace-fail ${escapeShellArg worktreePathAnchor} ${escapeShellArg worktreePathPatch}
        '';

      postBuild =
        (old.postBuild or "")
        + ''
          substituteInPlace node_modules/.pnpm/effect@*/node_modules/effect/dist/unstable/cli/internal/completions/zsh.js \
            --replace-fail ${escapeShellArg completionSlotAnchor} ${escapeShellArg completionSlotPatch}
        '';

      postFixup =
        (old.postFixup or "")
        + ''
          wrapProgram "$out/bin/t3code-desktop" \
            --set-default T3CODE_PORT ${toString desktopPort}
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
