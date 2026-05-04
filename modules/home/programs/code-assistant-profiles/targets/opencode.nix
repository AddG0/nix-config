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

  skillInstallDir = name: "${config.xdg.configHome}/opencode/skills/${name}";

  substituteSkillDir = name:
    lib.replaceStrings ["\${SKILL_DIR}"] [(skillInstallDir name)];

  fallbackString = preferred: fallback:
    if preferred != null
    then preferred
    else fallback;

  renderAgent = name: agent:
    frontmatter.toFile {
      attrs = {
        description = fallbackString agent.description name;
        mode = "subagent";
        model = agent.model or null;
        reasoningEffort = agent.reasoningEffort or null;
        steps = agent.maxTurns or null;
      };
      body = readContent agent.prompt;
    };

  renderCommand = _: command:
    frontmatter.toFile {
      attrs = {
        description = command.description or null;
        agent = command.agent or null;
        model = command.model or null;
      };
      body = readContent command.content;
    };

  renderSkillContent = name: skill: let
    publicName = skill.name or name;
    description = fallbackString skill.description publicName;
    promptBody = substituteSkillDir name (readContent skill.prompt);
    usageSection =
      if guidance == []
      then null
      else "## Usage\n${lib.concatStringsSep "\n\n" guidance}";
    guidance = lib.filter (line: line != null && line != "") [
      skill.whenToUse or null
      (
        if (skill.paths or []) == []
        then null
        else "Applies to: ${lib.concatStringsSep ", " skill.paths}"
      )
      (
        if (skill.invocation.model or true)
        then null
        else "Manual invocation only."
      )
      (
        if (skill.invocation.user or true)
        then null
        else "Background skill; not intended for direct user invocation."
      )
    ];
    body = lib.concatStringsSep "\n\n" (lib.filter (part: part != null && part != "") [promptBody usageSection]);
    rendered = frontmatter.toFile {
      attrs = {
        name = publicName;
        inherit description;
        compatibility = "opencode";
        metadata = {
          context = skill.context or null;
          model = skill.model or null;
          agent = skill.agent or null;
          reasoningEffort = skill.reasoningEffort or null;
          version = skill.version or null;
        };
      };
      inherit body;
    };
  in
    if (skill.resourcesRoot or null) != null
    then
      toString (pkgs.runCommand "opencode-skill-${lib.strings.sanitizeDerivationName name}" {} ''
                  mkdir -p "$out"
                  cp -R "${skill.resourcesRoot}/." "$out/"
                  rm -f "$out/SKILL.md"
                  cat > "$out/SKILL.md" <<'EOF'
        ${rendered}
        EOF
      '')
    else rendered;

  renderRule = name: rule: let
    body = readContent rule.content;
    header = lib.optional (rule.paths != []) "Applies to: ${lib.concatStringsSep ", " rule.paths}";
    title = lib.optional (rule.description != null || rule.paths != []) "## ${rule.description or name}";
    sections = lib.filter (part: part != "") (title ++ header ++ [body]);
  in
    lib.concatStringsSep "\n\n" sections;

  adaptMcp = lib.mapAttrs (
    _: server:
      if server.type == "remote"
      then {
        type = "remote";
        inherit (server) url;
      }
      else
        {
          type = "local";
          command = [server.command] ++ server.args;
        }
        // lib.optionalAttrs (server.env != {}) {environment = server.env;}
  ) (profile.mcpServers or {});

  adaptLsp = lib.mapAttrs (
    _: server:
      {
        command = [server.command] ++ server.args;
      }
      // lib.optionalAttrs (server.env != {}) {inherit (server) env;}
      // lib.optionalAttrs (server.extensionToLanguage != {}) {extensions = lib.attrNames server.extensionToLanguage;}
  ) (profile.lspServers or {});

  allSkills = profile.skills or {};
  userInvocableSkills = lib.filterAttrs (_: skill: skill.invocation.user) allSkills;

  derivedSkillCommands =
    lib.mapAttrs' (
      name: skill: let
        commandName = skill.name;
        command = {
          description = fallbackString skill.description commandName;
          inherit (skill) argumentHint agent model allowedTools;
          content = {
            text = substituteSkillDir name (readContent skill.prompt);
            source = null;
          };
        };
      in
        lib.nameValuePair commandName command
    )
    userInvocableSkills;

  commands = derivedSkillCommands // (profile.commands or {});

  combinedRules = lib.concatStringsSep "\n\n" (
    lib.filter (s: s != "") (
      lib.optional ((profile.instructions.text or null) != null) profile.instructions.text
      ++ lib.mapAttrsToList renderRule (profile.rules or {})
    )
  );
in {
  config = lib.mkIf (codingCfg.enable && codingCfg.targets.opencode.enable && hasProfile) {
    programs.opencode = {
      agents = lib.mkDefault (lib.mapAttrs renderAgent (profile.agents or {}));
      commands = lib.mkDefault (lib.mapAttrs renderCommand commands);
      skills = lib.mkDefault (lib.mapAttrs renderSkillContent allSkills);
      context = lib.mkDefault combinedRules;
      settings = {
        mcp = lib.mkDefault adaptMcp;
        lsp = lib.mkDefault adaptLsp;
      };
    };
  };
}
