{
  lib,
  pkgs,
  ...
}: let
  python = pkgs.python3.withPackages (ps: [ps.pyyaml]);
  skill = lib.custom.ai.fromClaudeSkillFile ./skills/code-assistant-configurator/prompt.md;
in {
  programs.code-assistant-profiles.addons.code-assistant-configurator = {
    skills.code-assistant-configurator =
      skill
      // {
        # The validator scripts need PyYAML, which no ambient python3 is guaranteed to have.
        prompt.text = lib.replaceStrings ["`python3 "] ["`${lib.getExe python} "] skill.prompt.text;
        resourcesRoot = ./skills/code-assistant-configurator/resources;
      };
  };
}
