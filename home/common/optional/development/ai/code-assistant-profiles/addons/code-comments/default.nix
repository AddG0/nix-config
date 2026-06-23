{
  lib,
  pkgs,
  ...
}: {
  programs.code-assistant-profiles.addons.code-comments = {
    skills."comments" = lib.custom.ai.fromClaudeSkillDir {
      inherit pkgs;
      source = ./skills/comments;
    };
  };
}
