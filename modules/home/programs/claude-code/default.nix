{customLib, ...}: {
  config,
  lib,
  pkgs,
  ...
}: let
  baseDir = ".config/claude-code/profiles";
  cfg = config.programs.claude-code-profiles;

  claudeSettingsHooks = import ./settings-hooks.nix {
    inherit lib;
    inherit (customLib) mkHookSchema;
  };

  optionsModule = import ./options.nix {
    inherit baseDir claudeSettingsHooks lib pkgs;
  };

  resolveProfileModule = import ./resolve-profile.nix {
    inherit cfg lib;
  };

  resolvedProfiles =
    lib.mapAttrs (
      name: profile:
        resolveProfileModule.mergeConfigs
        (cfg.profileDefaults.${name} or {})
        (resolveProfileModule.mergeWithBase name profile)
    )
    cfg.profiles;

  pluginCheck = import ./plugin-check.nix {inherit cfg lib pkgs;};

  profileFilesModule = import ./profile-files.nix {
    inherit claudeSettingsHooks lib pkgs pluginCheck resolvedProfiles;
  };

  wrapperScriptModule = import ./wrapper-script.nix {
    inherit baseDir cfg lib pkgs pluginCheck resolvedProfiles;
  };

  zshCompletionModule = import ./zsh-completion.nix {
    inherit cfg lib pkgs;
  };

  settingsHookAssertions = lib.unique (lib.concatLists (lib.mapAttrsToList (
      name: resolved:
        map (problem: "programs.claude-code-profiles profile '${name}' settings.hooks: ${problem}")
        (claudeSettingsHooks.problems "settings" (resolved.settings.hooks or {}))
    )
    resolvedProfiles));
in {
  inherit (optionsModule) options;

  config = lib.mkIf cfg.enable {
    programs.claude-code-profiles.resolved = resolvedProfiles;

    assertions =
      [
        {
          assertion = cfg.profiles != {};
          message = "At least one profile must be defined in programs.claude-code-profiles.profiles";
        }
        {
          assertion = cfg.profiles ? ${cfg.defaultProfile};
          message = "Default profile '${cfg.defaultProfile}' must exist in programs.claude-code-profiles.profiles";
        }
      ]
      ++ lib.mapAttrsToList (name: resolved: {
        assertion = !(resolved.memory.text != null && resolved.memory.source != null);
        message = "programs.claude-code-profiles profile '${name}' memory cannot define both text and source; CLAUDE.md would get both";
      })
      resolvedProfiles
      ++ map (message: {
        assertion = false;
        inherit message;
      })
      settingsHookAssertions;

    programs.claude-code-profiles.wrapperPackage = wrapperScriptModule.wrapperScript;

    home.packages = [wrapperScriptModule.wrapperScript] ++ lib.optional cfg.enableZshIntegration zshCompletionModule.zshCompletion;

    home.file = lib.foldl' (
      acc: name: acc // profileFilesModule.mkProfileFiles name cfg.profiles.${name}
    ) {} (lib.attrNames cfg.profiles);
  };
}
