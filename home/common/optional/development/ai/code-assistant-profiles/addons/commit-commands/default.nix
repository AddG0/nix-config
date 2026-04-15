{
  pkgs,
  lib,
  ...
}: let
  pluginDir = "${pkgs.claude-code-plugins}/share/claude-code/plugins/commit-commands/commands";
  inherit (lib.custom.ai) fromClaudeCommand;
in {
  commands = {
    "commit" = fromClaudeCommand "${pluginDir}/commit.md";
    "clean_gone" = fromClaudeCommand "${pluginDir}/clean_gone.md";
  };
}
