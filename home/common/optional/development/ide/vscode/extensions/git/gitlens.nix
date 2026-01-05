{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.eamodio.gitlens
  ];
  userSettings = {
    # Current line blame
    "gitlens.currentLine.enabled" = true;
    "gitlens.currentLine.format" = "\${author}, \${agoOrDate} • \${message}";

    # Code lens
    "gitlens.codeLens.enabled" = true;
    "gitlens.codeLens.authors.enabled" = true;
    "gitlens.codeLens.recentChange.enabled" = true;

    # Hovers
    "gitlens.hovers.currentLine.over" = "line";
    "gitlens.hovers.enabled" = true;

    # Blame annotations
    "gitlens.blame.format" = "\${author|10} \${agoOrDate|14-}";
    "gitlens.blame.heatmap.enabled" = true;

    # Status bar
    "gitlens.statusBar.enabled" = true;
    "gitlens.statusBar.command" = "gitlens.showQuickCommitDetails";

    # Disable telemetry
    "gitlens.telemetry.enabled" = false;

    # AI model - use Claude Sonnet 4.5
    "gitlens.ai.model" = "anthropic:claude-sonnet-4-5-20250929";
  };
}
