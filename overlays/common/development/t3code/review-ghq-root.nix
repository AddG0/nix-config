# Review diff preview/contents only allow cwds under the server's launch cwd, the
# managed worktree folders, or a registered project, so a sibling worktree
# (`<clone>--<branch>`, see worktree-paths.nix) is rejected whenever the launch
# cwd doesn't contain it; the desktop backend's is the Nix store. Also allow
# anything under the ghq root, resolved the way ghq itself does ($GHQ_ROOT, then
# `git config ghq.root`); unresolvable falls back to upstream behavior. A raw
# execFileSync instead of the codebase's ProcessRunner keeps the patch out of
# ReviewService's Effect dependency wiring. Drop with worktree-paths.nix.
#
# Patched in `unwrapped`: see README.md.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  ghqRootHelperAnchor = "/** @public Service construction is part of the canonical Effect module API. */\nexport const make = Effect.gen(function* () {";
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

  # A ghq root that cannot be resolved grants nothing, like upstream's managed roots.
  ghqRootCheckAnchor = builtins.concatStringsSep "\n" [
    "    if ("
    "      isWithinRoot(candidate, workspaceRoot) ||"
    "      worktreesRoots.some((root) => isWithinRoot(candidate, root))"
    "    ) {"
    "      return;"
    "    }"
  ];
  ghqRootCheckPatch = builtins.concatStringsSep "\n" [
    "    const ghqRootPath = resolveGhqRoot();"
    "    const ghqRoot ="
    "      ghqRootPath === null"
    "        ? null"
    "        : yield* canonicalizePath(ghqRootPath).pipe(Effect.orElseSucceed(() => null));"
    ""
    "    if ("
    "      isWithinRoot(candidate, workspaceRoot) ||"
    "      worktreesRoots.some((root) => isWithinRoot(candidate, root)) ||"
    "      (ghqRoot !== null && isWithinRoot(candidate, ghqRoot))"
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
