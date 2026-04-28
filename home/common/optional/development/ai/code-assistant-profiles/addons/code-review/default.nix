{
  pkgs,
  lib,
  ...
}: let
  cek = "${pkgs.context-engineering-kit}/share/claude-code";
  inherit (lib.custom.ai) fromClaudeAgent fromClaudeSkillFile;
in {
  programs.code-assistant-profiles.addons.code-review = {
    agents = {
      "bug-hunter" = fromClaudeAgent "${cek}/plugins/code-review/agents/bug-hunter.md";
      "code-quality-reviewer" = fromClaudeAgent "${cek}/plugins/code-review/agents/code-quality-reviewer.md";
      "contracts-reviewer" = fromClaudeAgent "${cek}/plugins/code-review/agents/contracts-reviewer.md";
      "historical-context-reviewer" = fromClaudeAgent "${cek}/plugins/code-review/agents/historical-context-reviewer.md";
      "security-auditor" = fromClaudeAgent "${cek}/plugins/code-review/agents/security-auditor.md";
      "test-coverage-reviewer" = fromClaudeAgent "${cek}/plugins/code-review/agents/test-coverage-reviewer.md";
    };

    commands."review-branch".content.source = ./commands/review-branch/prompt.md;

    skills = {
      "review-local-changes" = fromClaudeSkillFile "${cek}/plugins/code-review/skills/review-local-changes/SKILL.md";
      "review-pr" = fromClaudeSkillFile "${cek}/plugins/code-review/skills/review-pr/SKILL.md";
    };
  };
}
