{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.anthropic.claude-code
  ];
  userSettings = {
    # Use system claude binary (NixOS can't run bundled dynamically linked binary)
    "claudeCode.claudeProcessWrapper" = "${pkgs.claude-code}/bin/claude";

    # Open in sidebar (not as editor tab)
    "claudeCode.preferredLocation" = "sidebar";
  };
}
