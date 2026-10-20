# Change-request prose autolinks `#123` and bare shas, but GitLab's client
# definition opts out: its project routes sit under `/-/`, and it numbers merge
# requests with `!`, which the plugin never matches. Returning `<repo>/-` as the
# autolink base fixes issues and commits; `!123` links only under such a base.
# Drop once t3code autolinks GitLab itself.
#
# Patched in `unwrapped`: see README.md.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  definitionAnchor = "  referenceAutolinkRepositoryUrl: () => null,\n  reviewSummaryRequired: () => false,\n  checkoutCommandArgument: (input) => CHECKOUT_COMMAND.exec(input)?.[1]?.trim() ?? null,";
  definitionPatch = "  referenceAutolinkRepositoryUrl: (repositoryUrl) => `\${repositoryUrl.replace(/\\/+$/u, \"\")}/-`,\n  reviewSummaryRequired: () => false,\n  checkoutCommandArgument: (input) => CHECKOUT_COMMAND.exec(input)?.[1]?.trim() ?? null,";

  patternAnchor = "const AUTOLINK_CANDIDATE_PATTERN = /#[1-9]\\d*|[0-9a-f]{40}/giu;";
  patternPatch = "const AUTOLINK_CANDIDATE_PATTERN = /[#!][1-9]\\d*|[0-9a-f]{40}/giu;";

  matchAnchor = builtins.concatStringsSep "\n" [
    "      (matched: string, match: TextMatch) => {"
    "        const reference = matched.startsWith(\"#\");"
  ];
  matchPatch = builtins.concatStringsSep "\n" [
    "      (matched: string, match: TextMatch) => {"
    "        const mergeRequest = matched.startsWith(\"!\");"
    "        // Only GitLab's definition hands out a `/-` base."
    "        if (mergeRequest && !repositoryUrl.endsWith(\"/-\")) return false;"
    "        const reference = mergeRequest || matched.startsWith(\"#\");"
  ];

  urlAnchor = builtins.concatStringsSep "\n" [
    "          url: reference"
    "            ? `\${repositoryUrl}/issues/\${matched.slice(1)}`"
    "            : `\${repositoryUrl}/commit/\${matched}`,"
  ];
  urlPatch = builtins.concatStringsSep "\n" [
    "          url: mergeRequest"
    "            ? `\${repositoryUrl}/merge_requests/\${matched.slice(1)}`"
    "            : reference"
    "              ? `\${repositoryUrl}/issues/\${matched.slice(1)}`"
    "              : `\${repositoryUrl}/commit/\${matched}`,"
  ];
in {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace packages/source-control-gitlab/src/client/definition.ts \
            --replace-fail ${escapeShellArg definitionAnchor} ${escapeShellArg definitionPatch}

          substituteInPlace apps/web/src/components/pullRequest/pullRequestMarkdown.logic.ts \
            --replace-fail ${escapeShellArg patternAnchor} ${escapeShellArg patternPatch} \
            --replace-fail ${escapeShellArg matchAnchor} ${escapeShellArg matchPatch} \
            --replace-fail ${escapeShellArg urlAnchor} ${escapeShellArg urlPatch}
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
