{pkgs, ...}: {
  programs.claude-code = {
    commands = {
      "commit" = "${pkgs.claude-code-plugins}/share/claude-code/plugins/commit-commands/commands/commit.md";
      "clean_gone" = "${pkgs.claude-code-plugins}/share/claude-code/plugins/commit-commands/commands/clean_gone.md";
    };
  };
}
