{
  pkgs,
  lib,
  ...
}: let
  skillsCollection = "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/skills";
  inherit (lib.custom.ai) fromClaudeSkillDir;
in {
  agents = {
    "ddd-expert" = {
      prompt.source = ./agents/ddd-expert.md;
    };
  };

  skills = {
    "software-architecture" = fromClaudeSkillDir {
      inherit pkgs;
      source = "${skillsCollection}/adr-architecture";
    };
    "decision-matrix" = fromClaudeSkillDir {
      inherit pkgs;
      source = "${skillsCollection}/decision-matrix";
    };
    "forecast-premortem" = fromClaudeSkillDir {
      inherit pkgs;
      source = "${skillsCollection}/forecast-premortem";
    };
    "postmortem" = fromClaudeSkillDir {
      inherit pkgs;
      source = "${skillsCollection}/postmortem";
    };
    "security-threat-model" = fromClaudeSkillDir {
      inherit pkgs;
      source = "${skillsCollection}/security-threat-model";
    };
  };

  rules.architecture.content.source = ./rules/architecture.md;
}
