# Code Review addon - agents and commands for PR/code review
{pkgs, ...}: let
  cek = "${pkgs.context-engineering-kit}/share/claude-code";
in {
  agents = {
    "bug-hunter" = builtins.readFile "${cek}/plugins/code-review/agents/bug-hunter.md";
    "code-quality-reviewer" = builtins.readFile "${cek}/plugins/code-review/agents/code-quality-reviewer.md";
    "contracts-reviewer" = builtins.readFile "${cek}/plugins/code-review/agents/contracts-reviewer.md";
    "historical-context-reviewer" = builtins.readFile "${cek}/plugins/code-review/agents/historical-context-reviewer.md";
    "security-auditor" = builtins.readFile "${cek}/plugins/code-review/agents/security-auditor.md";
    "test-coverage-reviewer" = builtins.readFile "${cek}/plugins/code-review/agents/test-coverage-reviewer.md";
  };
  commands = {
    "review-local-changes" = builtins.readFile "${cek}/plugins/code-review/commands/review-local-changes.md";
    "review-branch" = ./commands/review-branch.md;
  };
}
