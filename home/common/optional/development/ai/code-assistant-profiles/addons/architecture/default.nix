{
  pkgs,
  lib,
  inputs,
  ...
}: let
  skillsCollection = "${inputs.claude-code-skills-collection}/skills";
  inherit (lib.custom.ai) fromClaudeSkillDir;
in {
  programs.code-assistant-profiles.addons.architecture = {
    agents = {
      "ddd-expert".prompt.source = ./agents/ddd-expert.md;
      "system-architect".prompt.source = ./agents/system-architect.md;
    };

    skills = {
      "adr" = {
        prompt.source = ./skills/adr/prompt.md;
        resourcesRoot = ./skills/adr/resources;
      };
      "architecture-standards" = {
        prompt.source = ./skills/architecture-standards/prompt.md;
        resourcesRoot = ./skills/architecture-standards/resources;
      };
      "software-architecture" = fromClaudeSkillDir {
        inherit pkgs;
        source = "${skillsCollection}/adr-architecture";
      };
      "decision-matrix" = fromClaudeSkillDir {
        inherit pkgs;
        source = "${skillsCollection}/decision-matrix";
      };
      "security-threat-model" = fromClaudeSkillDir {
        inherit pkgs;
        source = "${skillsCollection}/security-threat-model";
      };
    };

    rules.architecture.content.source = ./rules/architecture.md;
  };
}
