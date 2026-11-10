# How we write code. `comments` is always-on, not `paths`-scoped: a path rule triggers on the
# Read tool, which bypass mode's bash-first steer skips.
_: {
  imports = [./claude-code.nix];

  programs.code-assistant-profiles.addons.code-standards = {
    rules = {
      comments.content.source = ./rules/comments.md;
      change-scope.content.source = ./rules/change-scope.md;
      quality-standards.content.source = ./rules/quality-standards.md;
      self-documenting.content.source = ./rules/self-documenting.md;
    };

    # Advisory judgment at hand-off; the gate in self-documenting-gate/ checks only what a script can.
    agents."self-documenting-reviewer".prompt.source = ./agents/self-documenting-reviewer.md;

    skills."domain-language-steward" = {
      prompt.source = ./skills/domain-language-steward/prompt.md;
      resourcesRoot = ./skills/domain-language-steward/resources;
    };
  };
}
