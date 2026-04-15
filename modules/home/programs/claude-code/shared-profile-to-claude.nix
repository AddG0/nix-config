{
  lib,
  pkgs,
}: let
  inherit (lib.custom) frontmatter;
  readContent = spec:
    if spec.text != null
    then spec.text
    else builtins.readFile spec.source;

  renderAgent = name: agent:
    frontmatter.toFile {
      attrs = {
        inherit name;
        inherit (agent) description;
        tools =
          if agent.tools == []
          then null
          else agent.tools;
        skills =
          if (agent.skills or []) == []
          then null
          else agent.skills;
        model = agent.model or null;
        color = agent.color or null;
        category = agent.category or null;
      };
      body = readContent agent.prompt;
    };

  renderCommand = command:
    frontmatter.toFile {
      attrs = {
        description = command.description or null;
        "argument-hint" = command.argumentHint or null;
        "allowed-tools" =
          if (command.tools or []) == []
          then null
          else command.tools;
      };
      body = readContent command.content;
    };

  renderSkill = name: skill: let
    renderedSkill = frontmatter.toFile {
      attrs = {
        inherit name;
        inherit (skill) description;
        "argument-hint" = skill.argumentHint or null;
        context = skill.context or null;
        "allowed-tools" = lib.optional (skill.tools != []) (lib.concatStringsSep ", " skill.tools);
        model = skill.model or null;
        version = skill.version or null;
      };
      body = readContent skill.prompt;
    };
  in
    if (skill.resourcesRoot or null) != null
    then
      pkgs.runCommand "claude-skill-${lib.strings.sanitizeDerivationName name}" {} ''
                  mkdir -p "$out"
                  cp -R "${skill.resourcesRoot}/." "$out/"
                  rm -f "$out/SKILL.md" "$out/prompt.md"
                  cat > "$out/SKILL.md" <<'EOF'
        ${renderedSkill}
        EOF
      ''
    else renderedSkill;

  renderRule = rule:
    if rule.paths == []
    then
      if rule.content.source != null
      then rule.content.source
      else rule.content.text
    else
      frontmatter.toFile {
        attrs = {inherit (rule) paths;};
        body = readContent rule.content;
      };

  adaptMcpServer = server:
    if server.type == "remote"
    then
      {
        type = "http";
        inherit (server) url;
      }
      // lib.optionalAttrs (server.headers != {}) {inherit (server) headers;}
    else
      {
        inherit (server) command;
      }
      // lib.optionalAttrs (server.args != []) {inherit (server) args;}
      // lib.optionalAttrs (server.env != {}) {inherit (server) env;};

  adaptLspServer = server:
    {
      inherit (server) command;
    }
    // lib.optionalAttrs (server.args != []) {inherit (server) args;}
    // lib.optionalAttrs (server.env != {}) {inherit (server) env;}
    // lib.optionalAttrs (server.extensionToLanguage != {}) {inherit (server) extensionToLanguage;}
    // lib.optionalAttrs (server.startupTimeout != null) {inherit (server) startupTimeout;};
in
  profile: {
    description = profile.description or "";
    memory = {
      text = profile.instructions.text or null;
      source = profile.instructions.source or null;
    };
    mcpServers = lib.mapAttrs (_: adaptMcpServer) (profile.mcpServers or {});
    lspServers = lib.mapAttrs (_: adaptLspServer) (profile.lspServers or {});
    agents = lib.mapAttrs renderAgent (profile.agents or {});
    commands = lib.mapAttrs (_: renderCommand) (profile.commands or {});
    skills = lib.mapAttrs renderSkill (profile.skills or {});
    rules = lib.mapAttrs (_: renderRule) (profile.rules or {});
  }
