{
  cfg,
  frontmatter,
  lib,
}: let
  normalizeStringList = value:
    if value == null || value == ""
    then []
    else if lib.isList value
    then value
    else let
      trimmed = lib.strings.trim value;
      unwrapped =
        if lib.hasPrefix "[" trimmed && lib.hasSuffix "]" trimmed
        then lib.removeSuffix "]" (lib.removePrefix "[" trimmed)
        else trimmed;
      stripQuotes = item: let
        t = lib.strings.trim item;
      in
        if lib.hasPrefix "\"" t && lib.hasSuffix "\"" t
        then lib.removeSuffix "\"" (lib.removePrefix "\"" t)
        else if lib.hasPrefix "'" t && lib.hasSuffix "'" t
        then lib.removeSuffix "'" (lib.removePrefix "'" t)
        else t;
    in
      map stripQuotes (lib.splitString "," unwrapped);

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

  normalizeAgent = agent: let
    parsed = parseContentSource agent.prompt;
  in
    agent
    // {
      description = agent.description or parsed.attrs.description or null;
      prompt = normalizeContentSpec agent.prompt;
      tools =
        if agent.tools != []
        then agent.tools
        else normalizeStringList (parsed.attrs.tools or null);
      skills =
        if agent.skills != []
        then agent.skills
        else normalizeStringList (parsed.attrs.skills or null);
      model = agent.model or parsed.attrs.model or null;
      color = agent.color or parsed.attrs.color or null;
      category = agent.category or parsed.attrs.category or null;
    };

  normalizeCommand = command: let
    parsed = parseContentSource command.content;
  in
    command
    // {
      description = command.description or parsed.attrs.description or null;
      argumentHint = command.argumentHint or parsed.attrs."argument-hint" or null;
      tools =
        if command.tools != []
        then command.tools
        else normalizeStringList (parsed.attrs."allowed-tools" or parsed.attrs.tools or null);
      content = normalizeContentSpec command.content;
    };

  normalizeSkill = skill: let
    parsed = parseContentSource skill.prompt;
    normalizedName =
      if skill.name != null && skill.name != ""
      then skill.name
      else parsed.attrs.name or null;
    invocationUser =
      if !skill.invocation.user
      then false
      else if skill ? userInvocable && !skill.userInvocable
      then false
      else !(parsed.attrs ? "user-invocable") || parsed.attrs."user-invocable" != "false";
    invocationModel =
      if !skill.invocation.model
      then false
      else if skill ? disableModelInvocation && skill.disableModelInvocation
      then false
      else !(parsed.attrs ? "disable-model-invocation") || parsed.attrs."disable-model-invocation" != "true";
  in
    skill
    // {
      name = normalizedName;
      description = skill.description or parsed.attrs.description or null;
      whenToUse = skill.whenToUse or parsed.attrs.when_to_use or null;
      argumentHint = skill.argumentHint or parsed.attrs."argument-hint" or null;
      context = skill.context or parsed.attrs.context or null;
      effort = skill.effort or parsed.attrs.effort or null;
      agent = skill.agent or parsed.attrs.agent or null;
      version = skill.version or parsed.attrs.version or null;
      prompt = normalizeContentSpec skill.prompt;
      tools =
        if skill.tools != []
        then skill.tools
        else normalizeStringList (parsed.attrs."allowed-tools" or parsed.attrs.tools or null);
      invocation = {
        user = invocationUser;
        model = invocationModel;
      };
      paths =
        if skill.paths != []
        then skill.paths
        else normalizeStringList (parsed.attrs.paths or null);
      model = skill.model or parsed.attrs.model or null;
      userInvocable = invocationUser;
      disableModelInvocation = !invocationModel;
    };

  normalizeRule = rule: let
    parsed = parseContentSource rule.content;
  in
    rule
    // {
      description = rule.description or parsed.attrs.description or null;
      paths =
        if rule.paths != []
        then rule.paths
        else normalizeStringList (parsed.attrs.paths or null);
      content = normalizeContentSpec rule.content;
    };

  normalizeSharedConfig = sharedConfig:
    sharedConfig
    // {
      agents = lib.mapAttrs (_: normalizeAgent) (sharedConfig.agents or {});
      commands = lib.mapAttrs (_: normalizeCommand) (sharedConfig.commands or {});
      skills = lib.mapAttrs (_: normalizeSkill) (sharedConfig.skills or {});
      rules = lib.mapAttrs (_: normalizeRule) (sharedConfig.rules or {});
    };

  mergeConfigs = base: overlay: {
    description = overlay.description or base.description or "";
    instructions = let
      texts = lib.filter (t: t != null) [(base.instructions.text or null) (overlay.instructions.text or null)];
    in {
      text =
        if texts != []
        then lib.concatStringsSep "\n\n" texts
        else null;
      source = overlay.instructions.source or base.instructions.source or null;
    };
    mcpServers = lib.recursiveUpdate (base.mcpServers or {}) (overlay.mcpServers or {});
    lspServers = lib.recursiveUpdate (base.lspServers or {}) (overlay.lspServers or {});
    agents = lib.recursiveUpdate (base.agents or {}) (overlay.agents or {});
    commands = lib.recursiveUpdate (base.commands or {}) (overlay.commands or {});
    skills = lib.recursiveUpdate (base.skills or {}) (overlay.skills or {});
    rules = (base.rules or {}) // (overlay.rules or {});
  };

  resolveProfile = seen: name: profile:
    if builtins.elem name seen
    then throw "Profile '${name}' has a recursive extends chain: ${lib.concatStringsSep " -> " (seen ++ [name])}"
    else if profile.extends == null
    then profile
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
      mergeConfigs mergedParents profile;

  mergeWithBase = name: profile:
    normalizeSharedConfig (mergeConfigs cfg.baseConfig (resolveProfile [] name profile))
    // {inherit name;};
in {
  inherit mergeConfigs mergeWithBase normalizeSharedConfig resolveProfile;
}
