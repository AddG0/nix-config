{
  cfg,
  frontmatter,
  lib,
}: let
  inherit (frontmatter) normalizeStringList;

  valueOr = value: fallback:
    if value != null
    then value
    else fallback;

  parseContentSource = spec:
    if (spec.source or null) != null
    then frontmatter.fromFile spec.source
    else if (spec.text or null) != null
    then frontmatter.fromFile spec.text
    else {
      attrs = {};
      body = "";
    };

  normalizeContentSpec = spec: let
    parsed = parseContentSource spec;
  in
    if parsed.attrs == {}
    then spec
    else {
      text = parsed.body;
      source = null;
    };

  mkNormalizer = {
    contentField,
    scalarFields,
    listFields ? {},
    extra ? (_: _: {}),
  }: entity: let
    parsed = parseContentSource entity.${contentField};
    scalar =
      lib.mapAttrs (
        optName: fmKey: valueOr entity.${optName} (parsed.attrs.${fmKey} or null)
      )
      scalarFields;
    list =
      lib.mapAttrs (
        optName: fmKey:
          if entity.${optName} != []
          then entity.${optName}
          else normalizeStringList (parsed.attrs.${fmKey} or null)
      )
      listFields;
  in
    entity
    // scalar
    // list
    // {${contentField} = normalizeContentSpec entity.${contentField};}
    // (extra entity parsed);

  normalizeAgent = mkNormalizer {
    contentField = "prompt";
    scalarFields = {
      description = "description";
      model = "model";
      color = "color";
      category = "category";
    };
    listFields = {
      tools = "tools";
      skills = "skills";
    };
  };

  normalizeCommand = mkNormalizer {
    contentField = "content";
    scalarFields = {
      description = "description";
      argumentHint = "argument-hint";
    };
    listFields.allowedTools = "allowed-tools";
  };

  normalizeRule = mkNormalizer {
    contentField = "content";
    scalarFields.description = "description";
    listFields.paths = "paths";
  };

  normalizeSkill = mkNormalizer {
    contentField = "prompt";
    scalarFields = {
      description = "description";
      whenToUse = "when_to_use";
      argumentHint = "argument-hint";
      context = "context";
      effort = "effort";
      agent = "agent";
      version = "version";
      model = "model";
    };
    listFields = {
      allowedTools = "allowed-tools";
      paths = "paths";
    };
    extra = skill: parsed: let
      fmInvocation = parsed.attrs.invocation or {};
    in {
      name =
        if skill.name != null && skill.name != ""
        then skill.name
        else parsed.attrs.name or null;
      invocation = {
        user = skill.invocation.user && (fmInvocation.user or "true") != "false";
        model = skill.invocation.model && (fmInvocation.model or "true") != "false";
      };
    };
  };

  normalizeSharedConfig = sharedConfig:
    sharedConfig
    // {
      agents = lib.mapAttrs (_: normalizeAgent) (sharedConfig.agents or {});
      commands = lib.mapAttrs (_: normalizeCommand) (sharedConfig.commands or {});
      skills = lib.mapAttrs (_: normalizeSkill) (sharedConfig.skills or {});
      rules = lib.mapAttrs (_: normalizeRule) (sharedConfig.rules or {});
    };

  recursiveMerge = field: base: overlay:
    lib.recursiveUpdate (base.${field} or {}) (overlay.${field} or {});

  shallowMerge = field: base: overlay:
    (base.${field} or {}) // (overlay.${field} or {});

  mergeStrategies = {
    description = base: overlay: overlay.description or base.description or "";
    instructions = base: overlay: let
      texts = lib.filter (t: t != null) [
        (base.instructions.text or null)
        (overlay.instructions.text or null)
      ];
    in {
      text =
        if texts != []
        then lib.concatStringsSep "\n\n" texts
        else null;
      source = overlay.instructions.source or base.instructions.source or null;
    };
    mcpServers = recursiveMerge "mcpServers";
    lspServers = recursiveMerge "lspServers";
    agents = recursiveMerge "agents";
    commands = recursiveMerge "commands";
    skills = recursiveMerge "skills";
    rules = shallowMerge "rules";
  };

  mergeConfigs = base: overlay:
    lib.mapAttrs (_: f: f base overlay) mergeStrategies;

  applyInclude = base: profile: let
    withIncludes = lib.foldl mergeConfigs base (profile.include or []);
  in
    mergeConfigs withIncludes (removeAttrs profile ["include"]);

  resolveProfile = seen: name: profile:
    if builtins.elem name seen
    then throw "Profile '${name}' has a recursive extends chain: ${lib.concatStringsSep " -> " (seen ++ [name])}"
    else if profile.extends == null
    then applyInclude {} profile
    else let
      parentNames =
        if lib.isList profile.extends
        then profile.extends
        else [profile.extends];
      resolveParent = parentName: let
        parent = cfg.profiles.${parentName} or (throw "Profile '${name}' extends unknown profile '${parentName}'");
      in
        resolveProfile (seen ++ [name]) parentName parent;
      mergedParents = lib.foldl mergeConfigs {} (map resolveParent parentNames);
    in
      applyInclude mergedParents profile;

  mergeWithBase = name: profile:
    normalizeSharedConfig (mergeConfigs cfg.baseConfig (resolveProfile [] name profile))
    // {inherit name;};
in {
  inherit mergeConfigs mergeWithBase normalizeSharedConfig resolveProfile;
}
