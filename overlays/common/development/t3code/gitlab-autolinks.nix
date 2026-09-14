# Change-request prose autolinks `#123` and bare shas, but only for GitHub: the
# detail panel hands the renderer a repository URL solely when the provider is
# github, and the plugin builds github.com's paths. GitLab scopes project routes
# under `/-/` and numbers merge requests with `!`. Drop once t3code autolinks
# non-GitHub providers itself.
#
# Patched in `unwrapped`: see README.md.
_: _final: prev: let
  inherit (prev.lib) escapeShellArg;

  autolinkPatternAnchor = "const AUTOLINK_CANDIDATE_PATTERN = /#[1-9]\\d*|[0-9a-f]{40}/giu;";
  autolinkPatternPatch = builtins.concatStringsSep "\n" [
    autolinkPatternAnchor
    "const GITLAB_AUTOLINK_CANDIDATE_PATTERN = /[#!][1-9]\\d*|[0-9a-f]{40}/giu;"
  ];

  autolinkSignatureAnchor = builtins.concatStringsSep "\n" [
    "/** GitHub-style same-repository references for pull request prose, never code or authored links. */"
    "export function remarkPullRequestAutolinks(options: { readonly repositoryUrl: string }) {"
    "  const repositoryUrl = options.repositoryUrl.replace(/\\/+$/u, \"\");"
  ];
  autolinkSignaturePatch = builtins.concatStringsSep "\n" [
    "/** Same-repository references in change request prose, never code or authored links. */"
    "export function remarkPullRequestAutolinks(options: {"
    "  readonly repositoryUrl: string;"
    "  readonly provider: \"github\" | \"gitlab\";"
    "}) {"
    "  const repositoryUrl = options.repositoryUrl.replace(/\\/+$/u, \"\");"
    "  const gitlab = options.provider === \"gitlab\";"
    "  const referenceBaseUrl = gitlab ? `\${repositoryUrl}/-` : repositoryUrl;"
  ];

  autolinkMatchAnchor = builtins.concatStringsSep "\n" [
    "      AUTOLINK_CANDIDATE_PATTERN,"
    "      (matched: string, match: TextMatch) => {"
    "        const reference = matched.startsWith(\"#\");"
  ];
  autolinkMatchPatch = builtins.concatStringsSep "\n" [
    "      gitlab ? GITLAB_AUTOLINK_CANDIDATE_PATTERN : AUTOLINK_CANDIDATE_PATTERN,"
    "      (matched: string, match: TextMatch) => {"
    "        const mergeRequest = matched.startsWith(\"!\");"
    "        const reference = mergeRequest || matched.startsWith(\"#\");"
  ];

  autolinkUrlAnchor = builtins.concatStringsSep "\n" [
    "          url: reference"
    "            ? `\${repositoryUrl}/issues/\${matched.slice(1)}`"
    "            : `\${repositoryUrl}/commit/\${matched}`,"
  ];
  autolinkUrlPatch = builtins.concatStringsSep "\n" [
    "          url: mergeRequest"
    "            ? `\${referenceBaseUrl}/merge_requests/\${matched.slice(1)}`"
    "            : reference"
    "              ? `\${referenceBaseUrl}/issues/\${matched.slice(1)}`"
    "              : `\${referenceBaseUrl}/commit/\${matched}`,"
  ];

  # The context carried the repository URL alone, which left the provider with
  # nowhere to travel from the panel to the plugin.
  autolinkContextAnchor = "export const PullRequestMarkdownContext = createContext<string | null>(null);";
  autolinkContextPatch = builtins.concatStringsSep "\n" [
    "export type AutolinkRepository = {"
    "  readonly repositoryUrl: string;"
    "  readonly provider: \"github\" | \"gitlab\";"
    "};"
    ""
    "export const PullRequestMarkdownContext = createContext<AutolinkRepository | null>(null);"
  ];

  autolinkPluginAnchor = builtins.concatStringsSep "\n" [
    "  const repositoryUrl = useContext(PullRequestMarkdownContext);"
    "  const extraRemarkPlugins = useMemo<NonNullable<ReactMarkdownOptions[\"remarkPlugins\"]>>("
    "    () => (repositoryUrl ? [[remarkPullRequestAutolinks, { repositoryUrl }]] : []),"
    "    [repositoryUrl],"
    "  );"
  ];
  autolinkPluginPatch = builtins.concatStringsSep "\n" [
    "  const autolinkRepository = useContext(PullRequestMarkdownContext);"
    "  const extraRemarkPlugins = useMemo<NonNullable<ReactMarkdownOptions[\"remarkPlugins\"]>>("
    "    () => (autolinkRepository ? [[remarkPullRequestAutolinks, autolinkRepository]] : []),"
    "    [autolinkRepository],"
    "  );"
  ];

  autolinkImportAnchor = "import { PullRequestMarkdownContext } from \"./PullRequestMarkdown\";";
  autolinkImportPatch = builtins.concatStringsSep "\n" [
    "import {"
    "  PullRequestMarkdownContext,"
    "  type AutolinkRepository,"
    "} from \"./PullRequestMarkdown\";"
  ];

  # Memoised so the plugin list keeps its identity and the body is not reparsed
  # on every render of the panel.
  autolinkRepositoryAnchor = "  const repositoryUrl = detail === null ? null : changeRequestRepositoryUrl(detail.url);";
  autolinkRepositoryPatch = builtins.concatStringsSep "\n" [
    autolinkRepositoryAnchor
    "  const autolinkRepository = useMemo<AutolinkRepository | null>(() => {"
    "    const provider = detail?.provider;"
    "    return repositoryUrl !== null && (provider === \"github\" || provider === \"gitlab\")"
    "      ? { repositoryUrl, provider }"
    "      : null;"
    "  }, [detail?.provider, repositoryUrl]);"
  ];

  autolinkGateAnchor = "          <PullRequestMarkdownContext value={detail.provider === \"github\" ? repositoryUrl : null}>";
  autolinkGatePatch = "          <PullRequestMarkdownContext value={autolinkRepository}>";
in {
  t3code = prev.t3code.override {
    t3code-unwrapped = prev.t3code.unwrapped.overrideAttrs (old: {
      postPatch =
        (old.postPatch or "")
        + ''
          substituteInPlace apps/web/src/components/pullRequest/pullRequestMarkdown.logic.ts \
            --replace-fail ${escapeShellArg autolinkPatternAnchor} ${escapeShellArg autolinkPatternPatch} \
            --replace-fail ${escapeShellArg autolinkSignatureAnchor} ${escapeShellArg autolinkSignaturePatch} \
            --replace-fail ${escapeShellArg autolinkMatchAnchor} ${escapeShellArg autolinkMatchPatch} \
            --replace-fail ${escapeShellArg autolinkUrlAnchor} ${escapeShellArg autolinkUrlPatch}

          substituteInPlace apps/web/src/components/pullRequest/PullRequestMarkdown.tsx \
            --replace-fail ${escapeShellArg autolinkContextAnchor} ${escapeShellArg autolinkContextPatch} \
            --replace-fail ${escapeShellArg autolinkPluginAnchor} ${escapeShellArg autolinkPluginPatch}

          substituteInPlace apps/web/src/components/pullRequest/PullRequestDetailPanel.tsx \
            --replace-fail ${escapeShellArg autolinkImportAnchor} ${escapeShellArg autolinkImportPatch} \
            --replace-fail ${escapeShellArg autolinkRepositoryAnchor} ${escapeShellArg autolinkRepositoryPatch} \
            --replace-fail ${escapeShellArg autolinkGateAnchor} ${escapeShellArg autolinkGatePatch}
        '';
    });
    # Pinned to avoid a Rust rebuild for an identical binary.
    t3code-resource-monitor = prev.t3code.resourceMonitor;
  };
}
