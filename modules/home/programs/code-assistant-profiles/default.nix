{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.code-assistant-profiles;
  inherit (lib.custom) frontmatter;

  typesModule = import ./types.nix {
    inherit lib;
  };

  optionsModule = import ./options.nix {
    inherit lib pkgs typesModule;
  };

  resolveProfileModule = import ./resolve-profile.nix {
    inherit cfg frontmatter lib;
  };

  validationModule = import ./validation.nix {
    inherit cfg lib;
  };
in {
  imports = [
    ./targets/opencode.nix
  ];

  inherit (optionsModule) options;

  config = lib.mkIf cfg.enable {
    programs.code-assistant-profiles.resolved = lib.mapAttrs resolveProfileModule.mergeWithBase cfg.profiles;

    assertions =
      [
        {
          assertion = cfg.profiles != {};
          message = "At least one profile must be defined in programs.code-assistant-profiles.profiles";
        }
        {
          assertion = cfg.profiles ? ${cfg.defaultProfile};
          message = "Default profile '${cfg.defaultProfile}' must exist in programs.code-assistant-profiles.profiles";
        }
      ]
      ++ validationModule.validateSharedConfig "baseConfig" (resolveProfileModule.normalizeSharedConfig cfg.baseConfig)
      ++ lib.flatten (lib.mapAttrsToList (
          name: profile:
            validationModule.validateSharedConfig "profile '${name}'" (resolveProfileModule.normalizeSharedConfig profile)
        )
        cfg.profiles);
  };
}
