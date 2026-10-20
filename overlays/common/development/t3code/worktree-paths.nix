# Worktrees land beside the clone as <clone>--<branch> instead of under
# ~/.t3/worktrees, so gwq and `ghq list` see them like gwadd's. This overrides
# the worktreesDirectory setting, which only picks the parent of <repo>/<branch>.
#
# Patched in `unwrapped`: see README.md.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  # Anchors carry real indentation: '' blocks strip the common indent and stop
  # matching.
  repoNameAnchor = "    const repoName = path.basename(input.cwd);\n";

  # gitCommonDir-to-worktree and the GitCommandError handling both mirror
  # upstream's invalidateStatusStaticCaches. The cwd fallback keeps a resolution
  # failure from failing thread creation, which soft-deletes it and strands its id.
  worktreePathAnchor = "      worktreePath = path.join(parentDir, repoName, sanitizedBranch);";
  worktreePathPatch = builtins.concatStringsSep "\n" [
    "      const repositoryPaths = yield* resolveRepositoryPaths(input.cwd).pipe("
    "        Effect.catchTags({ GitCommandError: () => Effect.succeed(null) }),"
    "      );"
    "      const primaryWorktree ="
    "        repositoryPaths && path.basename(repositoryPaths.gitCommonDir) === \".git\""
    "          ? path.dirname(repositoryPaths.gitCommonDir)"
    "          : input.cwd;"
    "      worktreePath = `\${primaryWorktree}--\${sanitizedBranch}`;"
  ];
in {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace apps/server/src/vcs/GitVcsDriverCore.ts \
            --replace-fail ${escapeShellArg repoNameAnchor} "" \
            --replace-fail ${escapeShellArg worktreePathAnchor} ${escapeShellArg worktreePathPatch}
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
