{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./code-assistant-profiles
    ./claude-code
    ./codex.nix
    ./opencode.nix
  ];

  programs.zsh.shellAliases = {
    mcp-inspector = "${pkgs.nodejs}/bin/npx --yes @modelcontextprotocol/inspector";
  };

  home.packages = with pkgs;
    [
      # Development tools
      claude-code-router
      ollama-zsh-completion
      repomix
    ]
    ++ (lib.optionals pkgs.stdenv.isLinux) [claude-desktop];
}
