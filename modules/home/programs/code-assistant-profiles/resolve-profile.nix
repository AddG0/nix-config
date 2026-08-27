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

  emptyDocument = {
    attrs = {};
    body = "";
  };

  # Empty parses to nothing rather than throwing: this runs while the assertion
  # list is built, so a throw would pre-empt validation.nix's named message.
  parseContentSource = spec:
    if (spec.source or null) != null
    then frontmatter.fromFile spec.source
    else if (spec.text or null) != null
    then frontmatter.fromText spec.text
    else emptyDocument;

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
      reasoningEffort = "effort";
    };
    listFields = {
      tools = "tools";
      disallowedTools = "disallowedTools";
      skills = "skills";
    };
    extra = agent: parsed: let
      rawMaxTurns = parsed.attrs.maxTurns or null;
    in {
      maxTurns =
        if agent.maxTurns != null
        then agent.maxTurns
        else if rawMaxTurns == null
        then null
        else lib.toInt rawMaxTurns;
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
      reasoningEffort = "effort";
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
    # Never both at once: claude-code projects them onto one home.file entry,
    # which home-manager rejects. A lone source stays a source so it stays a link.
    instructions = base: overlay: let
      specOf = c: {
        text = c.instructions.text or null;
        source = c.instructions.source or null;
      };
      b = specOf base;
      o = specOf overlay;
      isEmpty = spec: spec.text == null && spec.source == null;
      read = spec:
        if spec.text != null
        then spec.text
        else builtins.readFile spec.source;
    in
      if isEmpty b
      then o
      else if isEmpty o
      then b
      else {
        text = lib.concatStringsSep "\n\n" [(read b) (read o)];
        source = null;
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

  # Exported so default.nix can assert every shared-profile field has a strategy;
  # mergeConfigs maps over these keys, so an unlisted field is silently dropped.
  mergeStrategyNames = lib.attrNames mergeStrategies;
}
