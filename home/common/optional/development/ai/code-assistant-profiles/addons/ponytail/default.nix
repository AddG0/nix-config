# Skills only; these upstream pieces are deliberately left out:
#   - SessionStart / SubagentStart / UserPromptSubmit hooks (auto-activate globally, and need node on the non-interactive PATH)
#   - ponytail-review (overlaps /code-review and /simplify)
#   - ponytail-gain (upstream's benchmark numbers), ponytail-help, statusline scripts
{
  pkgs,
  lib,
  inputs,
  ...
}: let
  ponytail = "${inputs.ponytail}/skills";
  inherit (lib.custom.ai) fromClaudeSkillDir;
  skill = name:
    fromClaudeSkillDir {
      inherit pkgs;
      source = "${ponytail}/${name}";
    };
in {
  programs.code-assistant-profiles.addons.ponytail = {
    skills = {
      "ponytail" = skill "ponytail";
      "ponytail-audit" = skill "ponytail-audit";
      "ponytail-debt" = skill "ponytail-debt";
    };
  };
}
