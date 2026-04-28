{
  cfg,
  lib,
}: let
  recursiveMerge = field: base: overlay:
    lib.recursiveUpdate (base.${field} or {}) (overlay.${field} or {});

  shallowMerge = field: base: overlay:
    (base.${field} or {}) // (overlay.${field} or {});

  concatLists = field: base: overlay:
    (base.${field} or []) ++ (overlay.${field} or []);

  mergeStrategies = {
    settings = recursiveMerge "settings";
    memory = base: overlay: let
      texts = lib.filter (t: t != null) [(base.memory.text or null) (overlay.memory.text or null)];
    in {
      text =
        if texts != []
        then lib.concatStringsSep "\n\n" texts
        else null;
      source = overlay.memory.source or base.memory.source or null;
    };
    mcpServers = shallowMerge "mcpServers";
    lspServers = shallowMerge "lspServers";
    agents = shallowMerge "agents";
    commands = shallowMerge "commands";
    hooks = shallowMerge "hooks";
    skills = shallowMerge "skills";
    rules = shallowMerge "rules";
    outputStyles = shallowMerge "outputStyles";
    pluginDirs = concatLists "pluginDirs";
    extraFiles = shallowMerge "extraFiles";
  };

  mergeConfigs = base: overlay:
    lib.mapAttrs (_: f: f base overlay) mergeStrategies;

  applyInclude = base: profile: let
    withIncludes = lib.foldl mergeConfigs base (profile.include or []);
  in
    mergeConfigs withIncludes (removeAttrs profile ["include"]);

  resolveProfile = name: profile:
    if profile.extends == null
    then applyInclude {} profile
    else let
      extendsList =
        if lib.isList profile.extends
        then profile.extends
        else [profile.extends];
      resolveOne = parentName: let
        parent = cfg.profiles.${parentName} or (throw "Profile '${name}' extends unknown profile '${parentName}'");
      in
        resolveProfile parentName parent;
      resolved = lib.foldl mergeConfigs {} (map resolveOne extendsList);
    in
      applyInclude resolved profile;

  mergeWithBase = name: profile: let
    resolved = resolveProfile name profile;
  in
    mergeConfigs cfg.baseConfig resolved;
in {
  inherit mergeConfigs mergeWithBase resolveProfile;
}
