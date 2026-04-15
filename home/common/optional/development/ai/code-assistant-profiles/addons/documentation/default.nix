{
  pkgs,
  lib,
  ...
}: let
  cek = "${pkgs.context-engineering-kit}/share/claude-code";
  skillsCollection = "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/skills";
  inherit (lib.custom.ai) fromClaudeSkillDir fromClaudeSkillFile;
in {
  agents = {
    "doc-reviewer" = {
      prompt.source = ./agents/doc-reviewer.md;
    };
  };

  skills = {
    "update-docs" = fromClaudeSkillFile "${cek}/plugins/docs/skills/update-docs/SKILL.md";
    "write-concisely" = fromClaudeSkillFile "${cek}/plugins/docs/skills/write-concisely/SKILL.md";
    "changelog-generator" = {
      prompt.source = ./skills/changelog-generator/prompt.md;
    };
    "information-architecture" = fromClaudeSkillDir {
      inherit pkgs;
      source = "${skillsCollection}/information-architecture";
    };
  };
}
