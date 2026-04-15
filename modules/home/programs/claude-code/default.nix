{
  config,
  lib,
  pkgs,
  ...
}: let
  baseDir = ".config/claude-code/profiles";
  cfg = config.programs.claude-code-profiles;
  codingCfg = config.programs.code-assistant-profiles;

  optionsModule = import ./options.nix {
    inherit baseDir lib pkgs;
  };

  resolveProfileModule = import ./resolve-profile.nix {
    inherit cfg lib;
  };

  sharedProfileToClaude = import ./shared-profile-to-claude.nix {
    inherit lib pkgs;
  };

  sharedOverlayFor = name:
    if !codingCfg.enable
    then {}
    else if codingCfg.resolved ? ${name}
    then sharedProfileToClaude codingCfg.resolved.${name}
    else {};

  resolvedProfiles =
    lib.mapAttrs (
      name: profile:
        resolveProfileModule.mergeConfigs
        (sharedOverlayFor name)
        (resolveProfileModule.mergeWithBase name profile)
    )
    cfg.profiles;

  profileFilesModule = import ./profile-files.nix {
    inherit lib pkgs resolvedProfiles;
  };

  wrapperScriptModule = import ./wrapper-script.nix {
    inherit baseDir cfg lib pkgs resolvedProfiles;
  };

  zshCompletionModule = import ./zsh-completion.nix {
    inherit cfg lib pkgs;
  };
in {
  inherit (optionsModule) options;

  config = lib.mkIf cfg.enable {
    programs.claude-code-profiles.resolved = resolvedProfiles;

    assertions = [
      {
        assertion = cfg.profiles != {};
        message = "At least one profile must be defined in programs.claude-code-profiles.profiles";
      }
      {
        assertion = cfg.profiles ? ${cfg.defaultProfile};
        message = "Default profile '${cfg.defaultProfile}' must exist in programs.claude-code-profiles.profiles";
      }
    ];

    home.packages = [wrapperScriptModule.wrapperScript] ++ lib.optional cfg.enableZshIntegration zshCompletionModule.zshCompletion;

    home.file = lib.foldl' (
      acc: name: acc // profileFilesModule.mkProfileFiles name cfg.profiles.${name}
    ) {} (lib.attrNames cfg.profiles);
  };
}
