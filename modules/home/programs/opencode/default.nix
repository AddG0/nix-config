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

  renderAgent = name: agent:
    frontmatter.toFile {
      attrs = {
        description = fallbackString agent.description name;
        mode = "subagent";
        category = agent.category or null;
        skills =
          if (agent.skills or []) == []
          then null
          else agent.skills;
      };
      body = readContent agent.prompt;
    };

  renderCommand = _: command: let
    attrs = {
      description = command.description or null;
      "argument-hint" = command.argumentHint or null;
      "allowed-tools" =
        if (command.tools or []) == []
        then null
        else command.tools;
    };
  in
    frontmatter.toFile {
      inherit attrs;
      body = readContent command.content;
    };

  renderSkillContent = name: skill: let
    rendered = frontmatter.toFile {
      attrs = {
        inherit name;
        description = fallbackString skill.description name;
        compatibility = "opencode";
        metadata = {
          "argument-hint" = skill.argumentHint or null;
          context = skill.context or null;
          model = skill.model or null;
          tools =
            if skill.tools == []
            then null
            else skill.tools;
          version = skill.version or null;
        };
      };
      body = readContent skill.prompt;
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

  combinedRules = lib.concatStringsSep "\n\n" (
    lib.filter (s: s != "") (
      lib.optional ((profile.instructions.text or null) != null) profile.instructions.text
      ++ lib.mapAttrsToList renderRule (profile.rules or {})
    )
  );
in {
  config = lib.mkIf (config.programs.opencode.enable && hasProfile) {
    programs.opencode = {
      agents = lib.mkDefault (lib.mapAttrs renderAgent (profile.agents or {}));
      commands = lib.mkDefault (lib.mapAttrs renderCommand (profile.commands or {}));
      skills = lib.mkDefault (lib.mapAttrs renderSkillContent (profile.skills or {}));
      rules = lib.mkDefault combinedRules;
      settings = {
        mcp = lib.mkDefault adaptMcp;
        lsp = lib.mkDefault adaptLsp;
      };
    };
  };
}
