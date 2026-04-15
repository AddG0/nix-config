{
  cfg,
  lib,
}: let
  mergeConfigs = base: overlay: {
    settings = lib.recursiveUpdate (base.settings or {}) (overlay.settings or {});
    memory = let
      texts = lib.filter (t: t != null) [(base.memory.text or null) (overlay.memory.text or null)];
    in {
      text =
        if texts != []
        then lib.concatStringsSep "\n\n" texts
        else null;
      source = overlay.memory.source or base.memory.source or null;
    };
    mcpServers = (base.mcpServers or {}) // (overlay.mcpServers or {});
    lspServers = (base.lspServers or {}) // (overlay.lspServers or {});
    agents = (base.agents or {}) // (overlay.agents or {});
    commands = (base.commands or {}) // (overlay.commands or {});
    hooks = (base.hooks or {}) // (overlay.hooks or {});
    skills = (base.skills or {}) // (overlay.skills or {});
    rules = (base.rules or {}) // (overlay.rules or {});
    outputStyles = (base.outputStyles or {}) // (overlay.outputStyles or {});
    pluginDirs = (base.pluginDirs or []) ++ (overlay.pluginDirs or []);
    extraFiles = (base.extraFiles or {}) // (overlay.extraFiles or {});
  };

  resolveProfile = name: profile:
    if profile.extends == null
    then profile
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
      mergeConfigs resolved profile;

  mergeWithBase = name: profile: let
    resolved = resolveProfile name profile;
  in
    mergeConfigs cfg.baseConfig resolved;
in {
  inherit mergeConfigs mergeWithBase resolveProfile;
}
