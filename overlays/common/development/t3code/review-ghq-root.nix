# Review diff preview/contents only allow cwds under the server's launch cwd or
# ~/.t3/worktrees, so a sibling worktree (`<clone>--<branch>`, see
# worktree-paths.nix) is rejected whenever the launch cwd doesn't contain it.
# Also allow anything under the ghq root, resolved the way ghq itself does
# ($GHQ_ROOT, then `git config ghq.root`); unresolvable falls back to upstream
# behavior. A raw execFileSync instead of the codebase's ProcessRunner keeps the
# patch out of ReviewService's Effect dependency wiring. Drop once t3code lets
# the worktree location (and with it this allowlist) be configured.
#
# Patched in `unwrapped`: see desktop-port.nix.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  ghqRootHelperAnchor = "export const make = Effect.gen(function* () {";
  ghqRootHelperPatch = builtins.concatStringsSep "\n" [
    "let cachedGhqRoot: string | null | undefined;"
    ""
    "/** The ghq root, by ghq's own precedence: $GHQ_ROOT, then `git config ghq.root`. */"
    "const resolveGhqRoot = (): string | null => {"
    "  if (cachedGhqRoot !== undefined) return cachedGhqRoot;"
    "  const fromEnv = process.env.GHQ_ROOT?.trim();"
    "  if (fromEnv) {"
    "    cachedGhqRoot = fromEnv;"
    "    return cachedGhqRoot;"
    "  }"
    "  try {"
    "    // --path expands `~` the way ghq does."
    "    const configured = execFileSync(\"git\", [\"config\", \"--path\", \"--get\", \"ghq.root\"], {"
    "      encoding: \"utf8\","
    "    }).trim();"
    "    cachedGhqRoot = configured === \"\" ? null : configured;"
    "  } catch {"
    "    // git exits non-zero when the key is unset; no ghq root means no extra allowance."
    "    cachedGhqRoot = null;"
    "  }"
    "  return cachedGhqRoot;"
    "};"
    ""
    ghqRootHelperAnchor
  ];

  ghqRootCheckAnchor = builtins.concatStringsSep "\n" [
    "    const [candidate, workspaceRoot, worktreesRoot] = yield* Effect.all(["
    "      canonicalizePath(cwd),"
    "      canonicalizePath(config.cwd),"
    "      canonicalizePath(config.worktreesDir),"
    "    ]);"
    ""
    "    if (isWithinRoot(candidate, workspaceRoot) || isWithinRoot(candidate, worktreesRoot)) {"
    "      return;"
    "    }"
  ];
  ghqRootCheckPatch = builtins.concatStringsSep "\n" [
    "    const ghqRoot = resolveGhqRoot();"
    "    const [candidate, workspaceRoot, worktreesRoot, ghqRootCanonical] = yield* Effect.all(["
    "      canonicalizePath(cwd),"
    "      canonicalizePath(config.cwd),"
    "      canonicalizePath(config.worktreesDir),"
    "      ghqRoot === null ? Effect.succeed(null) : canonicalizePath(ghqRoot),"
    "    ]);"
    ""
    "    if ("
    "      isWithinRoot(candidate, workspaceRoot) ||"
    "      isWithinRoot(candidate, worktreesRoot) ||"
    "      (ghqRootCanonical !== null && isWithinRoot(candidate, ghqRootCanonical))"
    "    ) {"
    "      return;"
    "    }"
  ];

  importAnchor = "import * as Context from \"effect/Context\";";
  importPatch = builtins.concatStringsSep "\n" [
    "import { execFileSync } from \"node:child_process\";"
    ""
    importAnchor
  ];
in {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace apps/server/src/review/ReviewService.ts \
            --replace-fail ${escapeShellArg importAnchor} ${escapeShellArg importPatch} \
            --replace-fail ${escapeShellArg ghqRootHelperAnchor} ${escapeShellArg ghqRootHelperPatch} \
            --replace-fail ${escapeShellArg ghqRootCheckAnchor} ${escapeShellArg ghqRootCheckPatch}
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
