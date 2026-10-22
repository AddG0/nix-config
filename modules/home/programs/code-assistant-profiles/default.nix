{customLib, ...}: {
  config,
  extendModules,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.code-assistant-profiles;
  inherit (customLib) frontmatter;

  profileSchema = import ./options/profile.nix {
    inherit lib;
  };

  optionsModule = import ./options {
    inherit lib profileSchema;
  };

  resolveProfileModule = import ./resolve-profile.nix {
    inherit cfg frontmatter lib;
  };

  validationModule = import ./validation.nix {
    inherit lib;
  };

  budgetsModule = import ./budgets.nix {
    inherit lib;
  };

  launcherModule = import ./launcher.nix {
    inherit lib pkgs;
  };

  inherit (import ./models.nix {inherit lib;}) targetForModel;

  runValidators = import ./run-validators.nix {inherit pkgs lib;};

  # Untyped until `resolved` takes it, so validation can name a bad value before the type throws on it.
  merged = lib.mapAttrs resolveProfileModule.mergeWithBase cfg.profiles;

  enabledAgents = lib.filter (name: cfg.targets.${name}.enable) launcherModule.targetNames;

  # mergeConfigs projects onto the strategy keys, so a field with no strategy resolves to its default.
  unmergedFields =
    lib.subtractLists resolveProfileModule.mergeStrategyNames
    (lib.attrNames profileSchema.profileContentOptions);

  # opencode renders only the default profile; Codex layers every other one over it.
  inlinedFor = name: cfg.targets.codex.enable || (cfg.targets.opencode.enable && name == cfg.defaultProfile);

  budgetFor = name: profile:
    budgetsModule.budgetMessages "profile '${name}'" cfg.budgets profile
    ++ lib.optionals (inlinedFor name)
    (budgetsModule.inlinedBudgetMessages "profile '${name}'" cfg.budgets profile);

  failure = message: {
    assertion = false;
    inherit message;
  };

  fieldTypeProblems = lib.mapAttrs (name: validationModule.fieldTypeProblems "profile '${name}'") merged;

  # Checked on their own, so an entry nothing includes is still typed and an error names where it was declared.
  layerTypeProblems =
    validationModule.fieldTypeProblems "baseConfig" cfg.baseConfig
    ++ lib.concatLists (lib.mapAttrsToList (name: validationModule.fieldTypeProblems "addon '${name}'") cfg.addons);

  budgetComplaints =
    lib.optionals (cfg.budgets.enforce != "off")
    (lib.flatten (lib.mapAttrsToList budgetFor cfg.resolved));

  modelKinds = ["agents" "commands" "skills"];
  unrouted = name: kind: entry: let
    model = cfg.resolved.${name}.${kind}.${entry}.model or null;
  in
    lib.elem kind modelKinds && model != null && targetForModel model == null;

  # A field one enabled target reads is not lost, so only what every one of them drops is reported; an unrouted model has its own warning.
  unreadFields = name: let
    reports = map (target: cfg.droppedFields.${target}.${name}) enabledAgents;
    droppedByAll = kind: entry: field: lib.all (report: lib.elem field (report.${kind}.${entry} or [])) reports && !(field == "model" && unrouted name kind entry);
  in
    lib.optionals (reports != []) (lib.concatLists (lib.mapAttrsToList (kind: entries:
      lib.concatLists (lib.mapAttrsToList (entry: fields:
        map (field: "${kind}.${entry}.${field}") (lib.filter (droppedByAll kind entry) fields))
      entries))
    (lib.head reports)));

  # Profiles inherit entries, so those with the same unread fields share one warning.
  unreadWarnings = let
    unread = lib.filter (entry: entry.fields != []) (lib.mapAttrsToList (name: _: {
      inherit name;
      fields = unreadFields name;
    }) (lib.filterAttrs (_: problems: problems == []) fieldTypeProblems));
    groups = lib.groupBy (entry: lib.concatStringsSep ", " entry.fields) unread;
  in
    lib.mapAttrsToList (fields: entries: "programs.code-assistant-profiles.profiles ${lib.concatMapStringsSep ", " (entry: "\"${entry.name}\"") entries}: no enabled target (${lib.concatStringsSep ", " enabledAgents}) reads these set fields, so they have no effect: ${fields}") groups;

  # Every target drops a model no target routes, so each is named with the profiles carrying it.
  unroutedModelWarnings = let
    found = lib.concatLists (lib.mapAttrsToList (name: _:
      lib.concatMap (kind:
        map (entry: {
          inherit name;
          key = "${kind}.${entry}.model = \"${cfg.resolved.${name}.${kind}.${entry}.model}\"";
        }) (lib.filter (unrouted name kind) (lib.attrNames cfg.resolved.${name}.${kind})))
      modelKinds) (lib.filterAttrs (_: problems: problems == []) fieldTypeProblems));
  in
    lib.optionals (enabledAgents != []) (lib.mapAttrsToList (key: entries: "programs.code-assistant-profiles.profiles ${lib.concatMapStringsSep ", " (entry: "\"${entry.name}\"") entries}: ${key} names a model no target routes (models.nix: Claude aliases and claude-* ids for claude-code, bare OpenAI ids for codex, provider/model ids for opencode), so every target drops it") (lib.groupBy (entry: entry.key) found));

  enabledValidators = lib.filter (validator: validator.enable) (lib.attrValues cfg.validators);
  staticConfig = lib.foldl' lib.recursiveUpdate {} (map (validator: validator.staticConfig) enabledValidators);
  checkedHome =
    if staticConfig == {}
    then config
    else (extendModules {modules = [staticConfig];}).config;

  launcher =
    if enabledAgents == []
    then null
    else
      launcherModule.mkLauncher {
        agents = enabledAgents;
        inherit (cfg) defaultAgent;
        profileBinDir = "${config.home.profileDirectory}/bin";

        # Default profile only: every target renders it, so the name exists whichever agent runs.
        skillNames =
          if cfg.resolved ? ${cfg.defaultProfile}
          then lib.attrNames cfg.resolved.${cfg.defaultProfile}.skills
          else [];
      };
in {
  imports = [
    (lib.modules.importApply ./targets/claude-code {inherit customLib;})
    (lib.modules.importApply ./targets/codex {inherit customLib;})
    (lib.modules.importApply ./targets/opencode {inherit customLib;})
  ];

  inherit (optionsModule) options;

  config = lib.mkMerge [
    {
      home.checks = lib.mkIf (cfg.checkConfig && enabledValidators != []) [
        (runValidators {
          name = config.home.username;
          homes.${config.home.username} = checkedHome;
        })
      ];
    }
    (lib.mkIf cfg.enable {
      programs.code-assistant-profiles.resolved = merged;
      programs.code-assistant-profiles.launcher = launcher;
      programs.code-assistant-profiles.fieldTypeProblems = fieldTypeProblems;

      home.packages = lib.optional (launcher != null) launcher;

      warnings = lib.optionals (cfg.budgets.enforce == "warn") budgetComplaints ++ unreadWarnings ++ unroutedModelWarnings;

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
        ++ lib.optionals (cfg.budgets.enforce == "error") (map failure budgetComplaints)
        ++ lib.flatten (lib.mapAttrsToList validationModule.collisionAssertions cfg.profiles)
        # Reading a badly typed field of `resolved` throws, which would hide the named message.
        ++ lib.flatten (lib.mapAttrsToList (
            name: problems:
              if problems == []
              then validationModule.validateSharedConfig "profile '${name}'" cfg.resolved.${name}
              else map failure problems
          )
          fieldTypeProblems)
        ++ map failure layerTypeProblems;
    })
  ];
}
