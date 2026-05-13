{
  config,
  lib,
  pkgs,
  ...
}: let
  codingCfg = config.programs.code-assistant-profiles;
  inherit (lib.custom) frontmatter;
  profileName = codingCfg.defaultProfile;
  hasProfile = codingCfg.enable && builtins.hasAttr profileName codingCfg.resolved;
  profile =
    if hasProfile
    then codingCfg.resolved.${profileName}
    else {};

  readContent = spec:
    if spec.text != null
    then spec.text
    else builtins.readFile spec.source;

  fallbackString = preferred: fallback:
    if preferred != null
    then preferred
    else fallback;

  # Match `programs.codex` (home-manager) location logic for codex >= 0.2.0:
  # XDG when the user prefers it, otherwise ~/.codex.
  codexHomeAbsolute =
    if config.home.preferXdgDirectories
    then "${config.xdg.configHome}/codex"
    else "${config.home.homeDirectory}/.codex";

  codexHomeRelative =
    if config.home.preferXdgDirectories
    then lib.removePrefix "${config.home.homeDirectory}/" config.xdg.configHome + "/codex"
    else ".codex";

  skillInstallDir = name: "${codexHomeAbsolute}/skills/${name}";

  substituteSkillDir = name:
    lib.replaceStrings ["\${SKILL_DIR}"] [(skillInstallDir name)];

  # Codex SKILL.md fields: name, description, argument-hint,
  # disable-model-invocation, user-invocable, allowed-tools, context,
  # agent, model. Anything else from the shared shape is dropped.
  renderSkillFrontmatter = name: skill: let
    publicName = skill.name or name;
    baseDescription = fallbackString skill.description publicName;
    whenToUse = skill.whenToUse or null;
    description =
      if whenToUse != null && whenToUse != ""
      then "${baseDescription}\n\n${whenToUse}"
      else baseDescription;
  in {
    name = publicName;
    inherit description;
    "argument-hint" = skill.argumentHint or null;
    "allowed-tools" =
      if (skill.allowedTools or []) == []
      then null
      else skill.allowedTools;
    "disable-model-invocation" =
      if (skill.invocation.model or true)
      then null
      else true;
    "user-invocable" =
      if (skill.invocation.user or true)
      then null
      else false;
    context = skill.context or null;
    agent = skill.agent or null;
    model = skill.model or null;
  };

  renderSkillText = name: skill:
    frontmatter.toFile {
      attrs = renderSkillFrontmatter name skill;
      body = substituteSkillDir name (readContent skill.prompt);
    };

  renderSkillDirectory = name: skill: let
    rendered = renderSkillText name skill;
  in
    pkgs.runCommand "codex-skill-${lib.strings.sanitizeDerivationName name}" {} ''
      mkdir -p "$out"
      cp -R "${skill.resourcesRoot}/." "$out/"
      rm -f "$out/SKILL.md"
      cat > "$out/SKILL.md" <<'EOF'
      ${rendered}
      EOF
    '';

  # Commands surface as user-invocable skills since ~/.codex/prompts/ is deprecated.
  # Avoid reading command.name — it's a readOnly option keyed off the parent attr name.
  commandToSkill = name: command: {
    inherit name;
    description = command.description or null;
    argumentHint = command.argumentHint or null;
    allowedTools = command.allowedTools or [];
    prompt = command.content;
  };

  # Agents surface as skills (Codex has no subagent concept). Drops the
  # fields with no Codex equivalent: tools, disallowedTools, maxTurns,
  # color, category, reasoningEffort, skills. Avoid reading agent.name —
  # it's a readOnly option keyed off the parent attr name.
  agentToSkill = name: agent: {
    inherit name;
    description = agent.description or null;
    model = agent.model or null;
    inherit (agent) prompt;
  };

  # Precedence on key collision: explicit skills > agents > commands.
  allSkillSpecs =
    (lib.mapAttrs commandToSkill (profile.commands or {}))
    // (lib.mapAttrs agentToSkill (profile.agents or {}))
    // (profile.skills or {});

  skillsWithResources = lib.filterAttrs (_: s: (s.resourcesRoot or null) != null) allSkillSpecs;
  skillsWithoutResources = lib.filterAttrs (_: s: (s.resourcesRoot or null) == null) allSkillSpecs;

  inlineSkills = lib.mapAttrs renderSkillText skillsWithoutResources;

  resourceSkillFiles =
    lib.mapAttrs' (
      name: skill:
        lib.nameValuePair "${codexHomeRelative}/skills/${name}" {
          source = renderSkillDirectory name skill;
          recursive = true;
        }
    )
    skillsWithResources;

  renderRule = name: rule: let
    body = readContent rule.content;
    header = lib.optional (rule.paths != []) "Applies to: ${lib.concatStringsSep ", " rule.paths}";
    title = lib.optional (rule.description != null || rule.paths != []) "## ${rule.description or name}";
    sections = lib.filter (part: part != "") (title ++ header ++ [body]);
  in
    lib.concatStringsSep "\n\n" sections;

  combinedRules = lib.concatStringsSep "\n\n" (
    lib.filter (s: s != "") (
      lib.optional ((profile.instructions.text or null) != null) profile.instructions.text
      ++ lib.mapAttrsToList renderRule (profile.rules or {})
    )
  );

  adaptMcpServer = server:
    if server.type == "remote"
    then
      {inherit (server) url;}
      // lib.optionalAttrs (server.headers != {}) {http_headers = server.headers;}
    else
      {inherit (server) command;}
      // lib.optionalAttrs (server.args != []) {inherit (server) args;}
      // lib.optionalAttrs (server.env != {}) {inherit (server) env;};

  adaptMcp = lib.mapAttrs (_: adaptMcpServer) (profile.mcpServers or {});

  settings = lib.optionalAttrs (adaptMcp != {}) {mcp_servers = adaptMcp;};
in {
  config = lib.mkIf (codingCfg.enable && codingCfg.targets.codex.enable && hasProfile) {
    programs.codex = {
      enable = lib.mkDefault true;
      context = combinedRules;
      skills = inlineSkills;
      inherit settings;
    };

    home.file = lib.mkIf config.programs.codex.enable resourceSkillFiles;
  };
}
