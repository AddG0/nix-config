# Caveman addon — opt-in terse output and memory file compression.
#
# Selectively pulls just the two useful skills from upstream:
#   caveman          — manual on-demand terse mode (invoke via /caveman or by name)
#   caveman-compress — compresses memory files (CLAUDE.md, etc.) by ~46%
#
# Skipped intentionally:
#   - SessionStart / UserPromptSubmit hooks (avoid auto-activating globally)
#   - caveman-commit / caveman-review (overlap with existing commit/review workflows)
#   - caveman-help, statusline scripts
{
  pkgs,
  lib,
  ...
}: let
  caveman = "${pkgs.caveman}/share/caveman/skills";
  inherit (lib.custom.ai) fromClaudeSkillDir;
in {
  programs.code-assistant-profiles.addons.caveman = {
    skills = {
      "caveman" = fromClaudeSkillDir {
        inherit pkgs;
        source = "${caveman}/caveman";
      };
      "caveman-compress" = fromClaudeSkillDir {
        inherit pkgs;
        source = "${caveman}/compress";
      };
    };
  };
}
