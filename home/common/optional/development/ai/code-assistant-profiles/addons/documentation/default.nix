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
      # Both write across the repo, so they run only when asked.
      "update-docs" = fromClaudeSkillFile "${cek}/plugins/docs/skills/update-docs/SKILL.md" // {invocation.model = false;};
      "write-concisely" = fromClaudeSkillFile "${cek}/plugins/docs/skills/write-concisely/SKILL.md";
      "write-for-people" = {
        prompt.source = ./skills/write-for-people/prompt.md;
        resourcesRoot = ./skills/write-for-people/resources;
      };
      "changelog-generator" = {
        prompt.source = ./skills/changelog-generator/prompt.md;
        invocation.model = false;
      };
      "information-architecture" =
        fromClaudeSkillDir {
          inherit pkgs;
          source = "${skillsCollection}/information-architecture";
        }
        // {description = "Structures and labels content so people can find it: navigation, taxonomy, sitemaps, card sorting and tree testing. Use when a site or app is hard to navigate or its sections need reorganizing.";};
    };
  };
}
