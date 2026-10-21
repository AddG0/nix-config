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

  # Empty parses to nothing: a throw here would pre-empt validation.nix's named message.
  parseContentSource = spec:
    if (spec.source or null) != null
    then frontmatter.fromFile spec.source
    else if (spec.text or null) != null
    then frontmatter.fromText spec.text
    else emptyDocument;

  normalizeContentSpec = spec: parsed:
    if parsed.attrs == {}
    then spec
    else {
      text = parsed.body;
      source = null;
    };

  # Frontmatter keys no field lifts (`derivedFields` names theirs) still reach Claude, typed as YAML reads them.
  mkNormalizer = {
    contentField,
    scalarFields,
    listFields ? {},
    derivedFields ? {},
    passthrough ? true,
  }: entry: let
    parsed = parseContentSource entry.${contentField};
    liftedKeys = lib.attrValues scalarFields ++ lib.attrValues listFields ++ lib.concatMap (field: field.keys) (lib.attrValues derivedFields);
    claudeOnly = lib.optionalAttrs passthrough (removeAttrs (parsed.typedAttrs or {}) (["name"] ++ liftedKeys));
    scalar =
      lib.mapAttrs (
        optName: fmKey: valueOr (entry.${optName} or null) (parsed.attrs.${fmKey} or null)
      )
      scalarFields;
    list =
      lib.mapAttrs (
        optName: fmKey:
          if (entry.${optName} or []) != []
          then entry.${optName}
          else normalizeStringList (parsed.attrs.${fmKey} or null)
      )
      listFields;
  in
    entry
    // scalar
    // list
    // {
      ${contentField} =
        if entry ? ${contentField}
        then normalizeContentSpec entry.${contentField} parsed
        else {};
    }
    // lib.optionalAttrs (claudeOnly != {}) {
      extra = (entry.extra or {}) // {claude-code = lib.recursiveUpdate claudeOnly (entry.extra.claude-code or {});};
    }
    // lib.mapAttrs (_: field: field.lift entry parsed) derivedFields;

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
    derivedFields.maxTurns = {
      keys = ["maxTurns"];
      # A non-numeric value stays a string, so validation names it instead of toInt throwing.
      lift = agent: parsed: let
        raw = parsed.attrs.maxTurns or null;
      in
        if (agent.maxTurns or null) != null
        then agent.maxTurns
        else if raw == null || builtins.match "[0-9]+" raw == null
        then raw
        else lib.toInt raw;
    };
  };

  normalizeCommand = mkNormalizer {
    contentField = "content";
    scalarFields = {
      description = "description";
      argumentHint = "argument-hint";
      model = "model";
      agent = "agent";
    };
    listFields.allowedTools = "allowed-tools";
  };

  normalizeRule = mkNormalizer {
    contentField = "content";
    passthrough = false;
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
      license = "license";
      compatibility = "compatibility";
    };
    listFields = {
      allowedTools = "allowed-tools";
      paths = "paths";
    };
    derivedFields = {
      name = {
        keys = ["name"];
        lift = skill: parsed:
          if (skill.name or null) != null && skill.name != ""
          then skill.name
          else parsed.attrs.name or null;
      };
      invocation = {
        # disable-model-invocation is Claude Code's own spelling, which vendored skills use.
        keys = ["invocation" "disable-model-invocation"];
        lift = skill: parsed: let
          fmInvocation = parsed.attrs.invocation or {};
          invocation = skill.invocation or {};
        in {
          user = (invocation.user or true) && (fmInvocation.user or "true") != "false";
          model =
            (invocation.model or true)
            && (fmInvocation.model or "true") != "false"
            && (parsed.attrs."disable-model-invocation" or "false") != "true";
        };
      };
      metadata = {
        keys = ["metadata"];
        lift = skill: parsed: let
          fmMetadata = parsed.attrs.metadata or {};
        in
          if lib.isAttrs fmMetadata
          then fmMetadata // (skill.metadata or {})
          else fmMetadata;
      };
    };
  };

  normalizeSharedConfig = sharedConfig:
    sharedConfig
    // {
      agents = lib.mapAttrs (_: normalizeAgent) (sharedConfig.agents or {});
      commands = lib.mapAttrs (_: normalizeCommand) (sharedConfig.commands or {});
      # The name goes in first, as the type default would, so a frontmatter `name` never renames the skill.
      skills = lib.mapAttrs (name: skill: normalizeSkill ({inherit name;} // skill)) (sharedConfig.skills or {});
      rules = lib.mapAttrs (_: normalizeRule) (sharedConfig.rules or {});
    };

  # A content block is replaced whole: a child's `text` must not sit beside its parent's `source`.
  recursiveMerge = field: base: overlay:
    lib.recursiveUpdateUntil (path: lhs: rhs: !(lib.isAttrs lhs && lib.isAttrs rhs) || (lib.length path == 2 && lib.elem (lib.last path) ["prompt" "content"]))
    (base.${field} or {}) (overlay.${field} or {});

  shallowMerge = field: base: overlay:
    (base.${field} or {}) // (overlay.${field} or {});

  instructionsSpecOf = c: {
    text = c.instructions.text or null;
    source = c.instructions.source or null;
  };

  isEmptySpec = spec: spec.text == null && spec.source == null;

  readSpec = spec:
    if spec.text != null
    then spec.text
    else builtins.readFile spec.source;

  # A merged layer carries its sections; a declared one is a single section, or none.
  sectionsOf = c:
    c.instructionSections or (let
      spec = instructionsSpecOf c;
    in
      lib.optional (!isEmptySpec spec) (readSpec spec));

  mergeStrategies = {
    description = base: overlay: overlay.description or base.description or "";
    # Never both at once (one home.file entry for claude-code); a lone source stays a link.
    instructions = base: overlay: let
      b = instructionsSpecOf base;
      o = instructionsSpecOf overlay;
    in
      if isEmptySpec b
      then o
      else if isEmptySpec o
      then b
      else {
        text = lib.concatStringsSep "\n\n" [(readSpec b) (readSpec o)];
        source = null;
      };
    instructionSections = base: overlay: sectionsOf base ++ sectionsOf overlay;
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

  # mergeConfigs drops an unlisted field, so default.nix asserts every field has a strategy.
  mergeStrategyNames = lib.attrNames mergeStrategies;
}
