# The push guard and the addons' settings hooks, evaluated through the claude-code module, for the unit and script tests.
{
  harness,
  lib,
  pkgs,
}: let
  fakeClaude = harness.stubs.claude;
  libWithCustom = harness.lib;
  claudeModule = harness.root + "/modules/home/programs/claude-code";
  addonDir = ../../../code-assistant-profiles/addons;
  pushGuard = ../.;

  claudeSettingsHooks = import (claudeModule + "/settings-hooks.nix") {
    inherit lib;
    inherit (libWithCustom.custom) mkHookSchema;
  };

  evalClaude = modules:
    harness.eval ([
        (harness.module (claudeModule + "/default.nix"))
        {
          programs.claude-code-profiles = {
            enable = true;
            package = fakeClaude;
          };
        }
      ]
      ++ modules);

  # The shape a settings hook user's module produced while settings was freeform JSON.
  legacySettingsHooksOf = module: path:
    lib.getAttrFromPath path
    (lib.evalModules {
      modules = [
        module
        {
          options.programs.claude-code-profiles = lib.mkOption {type = lib.types.anything;};
          config._module.args = {inherit pkgs;};
        }
      ];
    })
    .config
    .programs
    .claude-code-profiles;

  typedSettingsHooksOf = module: path: claudeSettingsHooks.render (lib.getAttrFromPath path (evalClaude [module]).programs.claude-code-profiles);

  settingsHookUsers = {
    git-push-guard = {
      module = pushGuard;
      path = ["baseConfig" "settings" "hooks"];
    };
    blind-choices = {
      module = addonDir + "/blind-choices/claude-code.nix";
      path = ["addons" "blind-choices" "settings" "hooks"];
    };
    design-notes = {
      module = addonDir + "/design-notes/claude-code.nix";
      path = ["addons" "design-notes" "settings" "hooks"];
    };
    code-standards = {
      module = addonDir + "/code-standards/claude-code.nix";
      path = ["addons" "code-standards" "settings" "hooks"];
    };
    spec-driven-dev = {
      module = addonDir + "/spec-driven-dev/claude-code.nix";
      path = ["addons" "spec-driven-dev" "settings" "hooks"];
    };
  };

  includeAddon = name: {config, ...}: {
    programs.claude-code-profiles.profiles.default.include = [config.programs.claude-code-profiles.addons.${name}];
  };

  guarded = evalClaude [pushGuard (addonDir + "/blind-choices/claude-code.nix") (includeAddon "blind-choices") {programs.claude-code-profiles.profiles.default = {};}];
  guardedSettings = guarded.home.file.".config/claude-code/profiles/default/settings.json".source;
  renderedOf = config:
    (import (claudeModule + "/profile-files.nix") {
      inherit claudeSettingsHooks lib pkgs;
      pluginCheck = import (claudeModule + "/plugin-check.nix") {
        inherit lib pkgs;
        cfg = config.programs.claude-code-profiles;
      };
      resolvedProfiles = {};
    }).renderSettings
    config.programs.claude-code-profiles.resolved.default.settings;

  # Claude Code's tools that run a shell command in the session's environment, so through the shim on PATH.
  shellTools = ["Bash" "Monitor" "PowerShell"];
  isGuardGroup = group: lib.any (handler: lib.hasSuffix "/bin/claude-ask-on-push-override" handler.command) group.hooks;
  guardGroups = lib.filter isGuardGroup ((renderedOf guarded).hooks.PreToolUse or []);
  pushGuardCommand = lib.concatMap (group: map (handler: handler.command) group.hooks) guardGroups;

  gitShim = lib.getExe (lib.findSingle (package: lib.getName package == "git") (throw "git-push-guard tests: no git shim in extraPath") (throw "git-push-guard tests: two git shims in extraPath") guarded.programs.claude-code-profiles.extraPath);

  # Reports the override as Claude would see it, so the wrapper's environment is what's tested.
  overrideReportingWrapper =
    (evalClaude [
      pushGuard
      {
        programs.claude-code-profiles.package = lib.mkForce (pkgs.writeShellScriptBin "claude" ''echo "''${ALLOW_GIT_PUSH-unset}"'');
        programs.claude-code-profiles.profiles.default = {};
      }
    ]).programs.claude-code-profiles.wrapperPackage;

  failedAssertions = config: map (a: a.message) (lib.filter (a: !a.assertion) config.assertions);
in {
  inherit addonDir claudeSettingsHooks evalClaude failedAssertions fakeClaude gitShim guardGroups guarded guardedSettings includeAddon legacySettingsHooksOf overrideReportingWrapper pushGuard pushGuardCommand renderedOf settingsHookUsers shellTools typedSettingsHooksOf;
}
