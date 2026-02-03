# Commit Commands addon - git commit workflow commands
{pkgs, ...}: {
  commands = {
    "commit" = "${pkgs.claude-code-plugins}/share/claude-code/plugins/commit-commands/commands/commit.md";
    "clean_gone" = "${pkgs.claude-code-plugins}/share/claude-code/plugins/commit-commands/commands/clean_gone.md";
  };
}
