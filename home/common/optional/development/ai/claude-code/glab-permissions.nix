# Read-only glab (GitLab CLI) subcommands are safe to auto-approve; anything
# that mutates state (MRs, issues, labels, repos) always prompts, regardless
# of auto-mode's classifier.
{
  programs.claude-code-profiles.baseConfig.settings.permissions = {
    allow = [
      "Bash(glab mr view:*)"
      "Bash(glab mr list:*)"
      "Bash(glab mr diff:*)"
      "Bash(glab issue view:*)"
      "Bash(glab issue list:*)"
      "Bash(glab ci view:*)"
      "Bash(glab ci status:*)"
      "Bash(glab pipeline list:*)"
      "Bash(glab pipeline status:*)"
      "Bash(glab repo view:*)"
    ];
    ask = [
      "Bash(glab mr create:*)"
      "Bash(glab mr merge:*)"
      "Bash(glab mr approve:*)"
      "Bash(glab mr close:*)"
      "Bash(glab mr update:*)"
      "Bash(glab mr revoke:*)"
      "Bash(glab issue create:*)"
      "Bash(glab issue close:*)"
      "Bash(glab issue update:*)"
      "Bash(glab label create:*)"
      "Bash(glab label delete:*)"
      "Bash(glab repo create:*)"
      "Bash(glab repo delete:*)"
    ];
  };
}
