{pkgs, ...}: {
  home.packages = with pkgs; [
    # Git tools
    lazygit # Git terminal UI.
    renovate # Dependency update tool.
    gitkraken # Git GUI.
    github-cli # GitHub CLI.
  ];
}
