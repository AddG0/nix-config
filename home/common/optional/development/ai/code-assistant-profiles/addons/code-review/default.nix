{
  lib,
  inputs,
  ...
}: let
  cek = "${inputs.context-engineering-kit}";
  inherit (lib.custom.ai) fromClaudeAgent fromClaudeSkillFile;
in {
  programs.code-assistant-profiles.addons.code-review = {
    agents = {
      "bug-hunter" = fromClaudeAgent "${cek}/plugins/review/agents/bug-hunter.md";
      "code-quality-reviewer" = fromClaudeAgent "${cek}/plugins/review/agents/code-quality-reviewer.md";
      "contracts-reviewer" = fromClaudeAgent "${cek}/plugins/review/agents/contracts-reviewer.md";
      "historical-context-reviewer" = fromClaudeAgent "${cek}/plugins/review/agents/historical-context-reviewer.md";
      "security-auditor" = fromClaudeAgent "${cek}/plugins/review/agents/security-auditor.md";
      "test-coverage-reviewer" = fromClaudeAgent "${cek}/plugins/review/agents/test-coverage-reviewer.md";
    };

    commands."review-branch".content.source = ./commands/review-branch/prompt.md;

    skills = {
      "review-local-changes" = fromClaudeSkillFile "${cek}/plugins/review/skills/review-local-changes/SKILL.md";
      "review-pr" = fromClaudeSkillFile "${cek}/plugins/review/skills/review-pr/SKILL.md";
    };
  };
}
