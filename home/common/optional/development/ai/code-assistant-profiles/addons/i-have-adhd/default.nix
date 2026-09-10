# A rule, not a skill: upstream ships it as /i-have-adhd, but an output style
# only works if it's loaded every turn. Everything else upstream is for other
# assistants, or is the always-on hook this replaces.
{
  inputs,
  lib,
  ...
}: {
  programs.code-assistant-profiles.addons.i-have-adhd = {
    rules."i-have-adhd".content.text =
      (lib.custom.ai.fromClaudeSkillFile "${inputs.i-have-adhd}/skills/i-have-adhd/SKILL.md").prompt.text;
  };
}
