# A resolved shared profile, rendered into Claude Code's artefacts.
{
  claudeSettingsHooks,
  customLib,
  lib,
  pkgs,
}: let
  inherit (customLib) frontmatter;
  skillResources = import ../../skill-resources.nix {inherit lib;};
  inherit (import ../../content.nix {inherit lib;}) always droppedFields readContent withExtraFor;

  # Claude Code names low/medium/high/xhigh/max; Codex's minimal and ultra have no Claude name.
  effortNames = ["low" "medium" "high" "xhigh" "max"];

  claudeEffort = effort:
    if lib.elem effort effortNames
    then effort
    else null;

  reads = {
    agents = {
      description = always;
      prompt = always;
      tools = always;
      disallowedTools = always;
      skills = always;
      model = always;
      color = always;
      reasoningEffort = effort: claudeEffort effort != null;
      maxTurns = always;
      "extra.claude-code" = always;
    };
    commands = {
      description = always;
      argumentHint = always;
      allowedTools = always;
      model = always;
      agent = always;
      subtask = always;
      content = always;
      "extra.claude-code" = always;
    };
    skills = {
      name = always;
      description = always;
      whenToUse = always;
      argumentHint = always;
      context = always;
      reasoningEffort = effort: claudeEffort effort != null;
      agent = always;
      invocation = always;
      paths = always;
      allowedTools = always;
      model = always;
      license = always;
      compatibility = always;
      metadata = always;
      version = always;
      prompt = always;
      resourcesRoot = always;
      "extra.claude-code" = always;
    };
    rules = {
      paths = always;
      content = always;
      "extra.claude-code" = always;
    };
    mcpServers = {
      type = always;
      command = always;
      args = always;
      env = always;
      url = always;
      headers = always;
      headersHelper = always;
      oauth = always;
      toolTimeout = always;
      enabled = always;
      "extra.claude-code" = always;
    };
    lspServers = {
      command = always;
      args = always;
      env = always;
      extensionToLanguage = always;
      initializationOptions = always;
      enabled = always;
      "extra.claude-code" = always;
    };
  };

  substituteSkillDir = lib.replaceStrings ["\${SKILL_DIR}"] ["\${CLAUDE_SKILL_DIR}"];

  withExtra = withExtraFor "claude-code";

  # Frontmatter hooks go through the settings hook type, so a typo fails here instead of loading silently.
  withHookedExtra = kind: name: entry: attrs: let
    extra = entry.extra.claude-code;
    hooks = claudeSettingsHooks.render (claudeSettingsHooks.typeHooks ["code-assistant-profiles" kind name "extra" "claude-code"] extra.hooks);
  in
    lib.recursiveUpdate attrs (removeAttrs extra ["hooks"] // lib.optionalAttrs (extra ? hooks && hooks != {}) {inherit hooks;});

  nonEmptyList = list:
    if list == []
    then null
    else list;

  # Claude Code has no per-entry switch, so a disabled server is left out.
  enabledOnly = lib.filterAttrs (_: server: server.enabled);

  renderInstructions = instructions: {inherit (instructions) text source;};

  renderRule = rule:
    if rule.paths == [] && rule.extra.claude-code == {}
    then
      if rule.content.source != null
      then rule.content.source
      else rule.content.text
    else
      frontmatter.toFile {
        attrs = withExtra rule {paths = nonEmptyList rule.paths;};
        body = readContent rule.content;
      };

  renderAgent = name: agent:
    frontmatter.toFile {
      attrs = withHookedExtra "agents" name agent {
        inherit name;
        inherit (agent) description;
        tools = nonEmptyList agent.tools;
        disallowedTools = nonEmptyList agent.disallowedTools;
        skills = nonEmptyList agent.skills;
        inherit (agent) model;
        inherit (agent) color;
        effort = claudeEffort agent.reasoningEffort;
        inherit (agent) maxTurns;
      };
      body = readContent agent.prompt;
    };

  renderSkill = name: skill: let
    metadata = skill.metadata // lib.optionalAttrs (skill.version != null) {inherit (skill) version;};
    renderedSkill = frontmatter.toFile {
      attrs = withHookedExtra "skills" name skill {
        inherit (skill) name;
        inherit (skill) description;
        when_to_use = skill.whenToUse;
        "argument-hint" = skill.argumentHint;
        inherit (skill) context;
        effort = claudeEffort skill.reasoningEffort;
        inherit (skill) agent;
        "user-invocable" = skill.invocation.user;
        "disable-model-invocation" = !skill.invocation.model;
        paths = nonEmptyList skill.paths;
        "allowed-tools" = nonEmptyList skill.allowedTools;
        inherit (skill) model;
        inherit (skill) license;
        inherit (skill) compatibility;
        metadata =
          if metadata == {}
          then null
          else metadata;
      };
      body = substituteSkillDir (readContent skill.prompt);
    };
  in
    if skill.resourcesRoot != null
    then
      skillResources.mkSkillDir {
        inherit pkgs name;
        inherit (skill) resourcesRoot;
        tool = "claude-code";
        skillMd = renderedSkill;
      }
    else renderedSkill;

  renderCommand = command:
    frontmatter.toFile {
      attrs = withExtra command {
        inherit (command) description;
        "argument-hint" = command.argumentHint;
        "allowed-tools" = nonEmptyList command.allowedTools;
        inherit (command) model;
        inherit (command) agent;
        context =
          if command.subtask == true
          then "fork"
          else null;
      };
      body = readContent command.content;
    };

  renderOauth = oauth:
    lib.filterAttrs (_: value: value != null) {
      inherit (oauth) clientId;
      inherit (oauth) callbackPort;
      scopes =
        if oauth.scopes == []
        then null
        else lib.concatStringsSep " " oauth.scopes;
    };

  renderMcpServer = server:
    withExtra server (
      (
        if server.type == "remote"
        then
          {
            type = "http";
            inherit (server) url;
          }
          // lib.optionalAttrs (server.headers != {}) {inherit (server) headers;}
          // lib.optionalAttrs (server.headersHelper != null) {inherit (server) headersHelper;}
          // lib.optionalAttrs (renderOauth server.oauth != {}) {oauth = renderOauth server.oauth;}
        else
          {
            inherit (server) command;
          }
          // lib.optionalAttrs (server.args != []) {inherit (server) args;}
          // lib.optionalAttrs (server.env != {}) {inherit (server) env;}
      )
      // lib.optionalAttrs (server.toolTimeout != null) {timeout = server.toolTimeout;}
    );

  renderLspServer = server:
    withExtra server (
      {
        inherit (server) command;
      }
      // lib.optionalAttrs (server.args != []) {inherit (server) args;}
      // lib.optionalAttrs (server.env != {}) {inherit (server) env;}
      // {inherit (server) extensionToLanguage;}
      // lib.optionalAttrs (server.initializationOptions != {}) {inherit (server) initializationOptions;}
    );

  renderRules = lib.mapAttrs (_: renderRule);
  renderAgents = lib.mapAttrs renderAgent;
  renderSkills = lib.mapAttrs renderSkill;
  renderCommands = lib.mapAttrs (_: renderCommand);
  renderMcpServers = servers: lib.mapAttrs (_: renderMcpServer) (enabledOnly servers);
  renderLspServers = servers: lib.mapAttrs (_: renderLspServer) (enabledOnly servers);
in
  profile: {
    instructions = renderInstructions profile.instructions;
    rules = renderRules profile.rules;
    agents = renderAgents profile.agents;
    skills = renderSkills profile.skills;
    commands = renderCommands profile.commands;
    mcpServers = renderMcpServers profile.mcpServers;
    lspServers = renderLspServers profile.lspServers;
    # Claude Code settings hooks live per profile in programs.claude-code-profiles, not in shared-profile fields.
    hooks = {};
    dropped = droppedFields reads profile;
  }
