# A rule, not a skill: as a skill this fired after the last edit in 3 of 74
# code-editing sessions. Always-on rather than `paths`-scoped because a
# path-scoped rule triggers on the Read tool, which bypass mode's bash-first
# steer skips — measured at 41% of sessions against 89% that touch code.
_: {
  imports = [./claude-code.nix];

  programs.code-assistant-profiles.addons.code-comments = {
    rules."comments".content.source = ./rules/comments.md;
  };
}
