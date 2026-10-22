# The push guard's settings hook, and the addons' settings hooks merged beside it.
{
  harness,
  lib,
  pkgs,
  ...
}: let
  inherit (import ./_cases.nix {inherit harness lib pkgs;}) evalClaude failedAssertions guardGroups guarded includeAddon legacySettingsHooksOf pushGuardCommand renderedOf settingsHookUsers shellTools typedSettingsHooksOf;
in {
  testSettingsHookUsersRenderTheShapeTheyWroteAsFreeformSettings = {
    expr = lib.mapAttrs (_: user: typedSettingsHooksOf user.module user.path) settingsHookUsers;
    expected = lib.mapAttrs (_: user: legacySettingsHooksOf user.module user.path) settingsHookUsers;
  };
  testPushGuardLandsInRenderedSettingsAsABashPreToolUseHook = {
    expr = map (lib.hasSuffix "/bin/claude-ask-on-push-override") pushGuardCommand;
    expected = [true];
  };
  testPushGuardMatchesEveryToolThatRunsAShellCommand = {
    expr = map (group: lib.splitString "|" group.matcher) guardGroups;
    expected = [shellTools];
  };
  testPushGuardAndAnAddonPreToolUseHookBothSurviveMerging = {
    expr = map (group: group.matcher) (renderedOf guarded).hooks.PreToolUse;
    expected = [(lib.concatStringsSep "|" shellTools) "AskUserQuestion"];
  };
  testMigratedSettingsHookUsersRaiseNoAssertions = {
    expr = failedAssertions (evalClaude (lib.mapAttrsToList (_: user: user.module) settingsHookUsers
      ++ map includeAddon ["blind-choices" "design-notes" "code-standards" "spec-driven-dev"]
      ++ [{programs.claude-code-profiles.profiles.default = {};}]));
    expected = [];
  };
}
