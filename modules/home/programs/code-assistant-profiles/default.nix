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
    inherit lib typesModule;
  };

  resolveProfileModule = import ./resolve-profile.nix {
    inherit cfg frontmatter lib;
  };

  validationModule = import ./validation.nix {
    inherit lib;
  };

  launcherModule = import ./launcher.nix {
    inherit lib pkgs;
  };

  enabledAgents = lib.filter (name: cfg.targets.${name}.enable) launcherModule.targetNames;

  # mergeConfigs projects onto the strategy keys, so a shared-profile field with
  # no strategy resolves to its type default no matter what a profile sets.
  unmergedFields =
    lib.subtractLists resolveProfileModule.mergeStrategyNames
    (lib.attrNames typesModule.sharedProfileOptions);

  budgetFor = name: profile:
    validationModule.budgetMessages "profile '${name}'" cfg.budgets profile;

  budgetComplaints =
    lib.optionals (cfg.budgets.enforce != "off")
    (lib.flatten (lib.mapAttrsToList budgetFor cfg.resolved));

  launcher =
    if enabledAgents == []
    then null
    else
      launcherModule.mkLauncher {
        agents = enabledAgents;
        inherit (cfg) defaultAgent;
        profileBinDir = "${config.home.profileDirectory}/bin";

        # Default profile only: it is the one every target renders, so a name
        # resolved here exists whichever agent runs.
        skillNames =
          if cfg.resolved ? ${cfg.defaultProfile}
          then lib.attrNames (cfg.resolved.${cfg.defaultProfile}.skills or {})
          else [];
      };
in {
  # targets/claude-code.nix is absent on purpose: modules/home/programs/claude-code
  # imports it, owning the option tree it feeds. These two adapt an upstream
  # home-manager module instead, so they self-register.
  imports = [
    ./targets/opencode.nix
    ./targets/codex.nix
  ];

  inherit (optionsModule) options;

  config = lib.mkIf cfg.enable {
    programs.code-assistant-profiles.resolved = lib.mapAttrs resolveProfileModule.mergeWithBase cfg.profiles;
    programs.code-assistant-profiles.launcher = launcher;

    home.packages = lib.optional (launcher != null) launcher;

    warnings = lib.optionals (cfg.budgets.enforce == "warn") budgetComplaints;

    assertions =
      [
        {
          assertion = unmergedFields == [];
          message = "code-assistant-profiles: resolve-profile.nix has no merge strategy for ${lib.concatStringsSep ", " unmergedFields}; profiles setting those fields would resolve to the type default. Add a strategy to mergeStrategies.";
        }
        {
          assertion = cfg.profiles != {};
          message = "At least one profile must be defined in programs.code-assistant-profiles.profiles";
        }
        {
          assertion = cfg.profiles ? ${cfg.defaultProfile};
          message = "Default profile '${cfg.defaultProfile}' must exist in programs.code-assistant-profiles.profiles";
        }
        {
          assertion = cfg.defaultAgent == null || cfg.targets.${cfg.defaultAgent}.enable;
          message = "programs.code-assistant-profiles.defaultAgent is '${toString cfg.defaultAgent}', so programs.code-assistant-profiles.targets.${toString cfg.defaultAgent}.enable must be true";
        }
      ]
      ++ lib.optionals (cfg.budgets.enforce == "error")
      (map (message: {
          assertion = false;
          inherit message;
        })
        budgetComplaints)
      ++ lib.flatten (lib.mapAttrsToList validationModule.collisionAssertions cfg.profiles)
      ++ validationModule.validateSharedConfig "baseConfig" (resolveProfileModule.normalizeSharedConfig cfg.baseConfig)
      ++ lib.flatten (lib.mapAttrsToList (
          name: profile:
            validationModule.validateSharedConfig "profile '${name}'" (resolveProfileModule.normalizeSharedConfig profile)
        )
        cfg.profiles);
  };
}
