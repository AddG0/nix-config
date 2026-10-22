# lib.custom.ai: reading a Claude skill's invocation flags off its frontmatter.
{lib, ...}: let
  invocationOf = path: (lib.custom.ai.fromClaudeSkillFile path).invocation;
in {
  testCarriesNativeManualFlag = {
    expr = invocationOf ./fixtures/ai/manual-skill/SKILL.md;
    expected = {model = false;};
  };

  testLeavesInvocationUnsetWhenUndeclared = {
    expr = invocationOf ./fixtures/ai/plain-skill/SKILL.md;
    expected = {};
  };
}
