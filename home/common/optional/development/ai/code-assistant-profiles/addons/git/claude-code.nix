# rules/git.md stands in for Claude's built-in git instructions, so profiles with the rule drop those.
_: {
  programs.claude-code-profiles.addons.git.settings.includeGitInstructions = false;
}
