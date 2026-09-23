# Condensed from github.com/ayghri/i-have-adhd (MIT) — upstream's 134-line
# SKILL.md is two thirds of the always-on budget on its own. A rule, not a
# skill: an output style only works if it loads every turn.
_: {
  programs.code-assistant-profiles.addons.i-have-adhd = {
    rules."i-have-adhd".content.source = ./rules/i-have-adhd.md;
  };
}
