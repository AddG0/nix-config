{
  pkgs,
  customPkgs,
  lib,
  ...
}: {
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
