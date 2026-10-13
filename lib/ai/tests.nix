{
  pkgs,
  lib,
  ...
}: let
  inherit (import ../. {inherit lib;}) ai;

  invocationOf = path: (ai.fromClaudeSkillFile path).invocation;

  failures = lib.runTests {
    testCarriesNativeManualFlag = {
      expr = invocationOf ./test-fixtures/manual-skill/SKILL.md;
      expected = {model = false;};
    };

    testLeavesInvocationUnsetWhenUndeclared = {
      expr = invocationOf ./test-fixtures/plain-skill/SKILL.md;
      expected = {};
    };
  };
in
  # Pure evaluation: a failure throws while the check is evaluated, before any build.
  lib.throwIf (failures != [])
  "lib/ai tests failed:\n${lib.generators.toPretty {} failures}"
  (pkgs.runCommand "lib-test-ai" {} "touch $out")
