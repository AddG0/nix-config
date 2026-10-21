{
  cfg,
  lib,
}: let
  # Lists append rather than replace: settings hooks and permissions come from several addons at once.
  deepMerge = a: b:
    if lib.isAttrs a && lib.isAttrs b
    then
      a
      // lib.mapAttrs (k: v:
        if a ? ${k}
        then deepMerge a.${k} v
        else v)
      b
    else if lib.isList a && lib.isList b
    then lib.unique (a ++ b)
    else b;

  recursiveMerge = field: base: overlay:
    deepMerge (base.${field} or {}) (overlay.${field} or {});

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
    hookScripts = shallowMerge "hookScripts";
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
