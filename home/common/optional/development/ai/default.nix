{
  pkgs,
  customPkgs,
  lib,
  ...
}: {
  imports = [
    ./ai-usagebar.nix
    ./code-assistant-profiles
    ./claude-code
    ./codex
    ./opencode
    ./t3code
    ./tmux-agent-sidebar.nix
  ];

  programs.zsh.shellAliases = {
    mcp-inspector = "${pkgs.nodejs}/bin/npx --yes @modelcontextprotocol/inspector";
  };

  home.packages = with pkgs;
    [
      # Development tools
      claude-code-router
      customPkgs.ollama-zsh-completion
      repomix
    ]
    ++ (lib.optionals pkgs.stdenv.hostPlatform.isLinux) [customPkgs.claude-desktop];
}
