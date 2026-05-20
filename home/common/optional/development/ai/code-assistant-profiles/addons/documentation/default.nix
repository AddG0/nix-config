{
  pkgs,
  lib,
  inputs,
  ...
}: let
  cek = "${inputs.context-engineering-kit}";
  skillsCollection = "${inputs.claude-code-skills-collection}/skills";
  inherit (lib.custom.ai) fromClaudeSkillDir fromClaudeSkillFile;
in {
  programs.code-assistant-profiles.addons.documentation = {
    agents."doc-reviewer".prompt.source = ./agents/doc-reviewer.md;

    skills = {
      "update-docs" = fromClaudeSkillFile "${cek}/plugins/docs/skills/update-docs/SKILL.md";
      "write-concisely" = fromClaudeSkillFile "${cek}/plugins/docs/skills/write-concisely/SKILL.md";
      "changelog-generator".prompt.source = ./skills/changelog-generator/prompt.md;
      "information-architecture" = fromClaudeSkillDir {
        inherit pkgs;
        source = "${skillsCollection}/information-architecture";
      };
    };
  };
}
