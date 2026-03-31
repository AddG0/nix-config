# Documentation addon - agents, skills, and commands for documentation workflows
{pkgs, ...}: let
  cek = "${pkgs.context-engineering-kit}/share/claude-code";
  skillsCollection = "${pkgs.claude-code-skills-collection}/share/claude-code/plugins/claude-code-skills-collection/skills";
in {
  agents = {
    "doc-reviewer" = ./agents/doc-reviewer.md;
  };

  skills = {
    "update-docs" = builtins.readFile "${cek}/plugins/docs/skills/update-docs/SKILL.md";
    "write-concisely" = builtins.readFile "${cek}/plugins/docs/skills/write-concisely/SKILL.md";
    "changelog-generator" = ./skills/changelog-generator;
    "writer" = "${skillsCollection}/writer";
    "information-architecture" = "${skillsCollection}/information-architecture";
  };
}
