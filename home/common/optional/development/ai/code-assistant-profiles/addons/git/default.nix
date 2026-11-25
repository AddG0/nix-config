# Keeps agents from committing or pushing unasked: a rule for every assistant, and Claude's push guard.
_: {
  # The guard is wrapper-wide, not per-profile: a profile without its hook could set ALLOW_GIT_PUSH unasked.
  imports = [./claude-code.nix ./push-guard];

  programs.code-assistant-profiles.addons.git = {
    rules.git.content.source = ./rules/git.md;
  };
}
