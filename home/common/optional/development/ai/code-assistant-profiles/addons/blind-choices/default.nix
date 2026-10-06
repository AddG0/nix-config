# Hide Claude's preferred option until the user has chosen, so the choice isn't anchored on it.
_: {
  imports = [./claude-code.nix];

  programs.code-assistant-profiles.addons.blind-choices = {
    rules."blind-choices".content.source = ./rules/blind-choices.md;
  };
}
