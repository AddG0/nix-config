# Change-request prose autolinks references through each host's definition, but
# GitLab's defines no `referenceAutolinks`, so nothing links: its project routes
# sit under `/-/`, and it numbers merge requests with `!`. This one links `#123`
# to the issue, `!123` to the merge request and a full SHA to its commit.
# Drop once t3code autolinks GitLab itself.
#
# Patched in `unwrapped`: see README.md.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  importAnchor = "  projectChangeRequestHost,\n} from \"@t3tools/source-control-core/shared/definition\";";
  importPatch = "  projectChangeRequestHost,\n  type ReferenceAutolink,\n} from \"@t3tools/source-control-core/shared/definition\";";

  kindAnchor = "const KIND = SourceControlProviderKind.make(\"gitlab\");";
  kindPatch = ''
    // `#12` names an issue, `!12` a merge request; GitLab links only full-length SHAs.
    const REFERENCE = /(?<![\w./\\-])(?:([#!])([1-9]\d*)|([a-f\d]{40}))(?![\w])/giu;
    const SHORT_SHA_LENGTH = 8;

    function gitLabReferenceAutolinks(
      text: string,
      repositoryUrl: string,
    ): ReadonlyArray<ReferenceAutolink> {
      const base = `''${repositoryUrl.replace(/\/+$/u, "")}/-`;
      const links: ReferenceAutolink[] = [];
      for (const match of text.matchAll(REFERENCE)) {
        const [matched, sigil, number, sha] = match;
        if (number) {
          links.push({
            index: match.index,
            text: matched,
            label: matched,
            url: `''${base}/''${sigil === "!" ? "merge_requests" : "issues"}/''${number}`,
            kind: "reference",
          });
        } else if (sha && /[a-f]/iu.test(sha)) {
          links.push({
            index: match.index,
            text: matched,
            label: sha.slice(0, SHORT_SHA_LENGTH),
            url: `''${base}/commit/''${sha}`,
            kind: "commit",
          });
        }
      }
      return links;
    }

    ${kindAnchor}'';

  definitionAnchor = "  authorProfileUrl: () => null,\n  reviewSummaryRequired: () => false,";
  definitionPatch = "  authorProfileUrl: () => null,\n  referenceAutolinks: gitLabReferenceAutolinks,\n  reviewSummaryRequired: () => false,";
in {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace packages/source-control-gitlab/src/shared/definition.ts \
            --replace-fail ${escapeShellArg importAnchor} ${escapeShellArg importPatch} \
            --replace-fail ${escapeShellArg kindAnchor} ${escapeShellArg kindPatch} \
            --replace-fail ${escapeShellArg definitionAnchor} ${escapeShellArg definitionPatch}
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
