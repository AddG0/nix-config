{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./claude-code
    ./opencode
    ./claude-desktop.nix
  ];

  programs.zsh.shellAliases = {
    mcp-inspector = "${pkgs.nodejs}/bin/npx --yes @modelcontextprotocol/inspector";
  };

  home.packages = with pkgs; [
    # Development tools
    claude-code-router
    repomix
    pkgs.claude-desktop
  ];
}
