{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./claude-code
    ./opencode
  ];

  programs.zsh.shellAliases = {
    mcp-inspector = "${pkgs.nodejs}/bin/npx --yes @modelcontextprotocol/inspector";
  };

  home.packages = with pkgs;
    [
      # Development tools
      claude-code-router
      repomix
    ]
    ++ (lib.optionals pkgs.stdenv.isLinux) [claude-desktop];
}
