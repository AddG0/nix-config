# A resolved shared profile, rendered into opencode's artefacts.
{
  codexSkillNames,
  customLib,
  lib,
  pkgs,
  plugins,
  skillsDir,
}: let
  inherit (customLib) frontmatter;
  skillResources = import ../../skill-resources.nix {inherit lib;};
  inherit (import ../../content.nix {inherit lib;}) always droppedFields inlinedSections readContent skillDescription withExtraFor;

  claudeToolPermissions = {
    Read = "read";
    Write = "edit";
    Edit = "edit";
    MultiEdit = "edit";
    NotebookEdit = "edit";
    Glob = "glob";
    Grep = "grep";
    Bash = "bash";
    Agent = "task";
    Task = "task";
    Skill = "skill";
    WebFetch = "webfetch";
    WebSearch = "websearch";
    TodoWrite = "todowrite";
    AskUserQuestion = "question";
    LSP = "lsp";
  };

  # opencode rejects a colour name it has no theme for, so each shared name gets a hex value.
  agentColorHex = {
    blue = "#0090FF";
    cyan = "#00A2C7";
    green = "#30A46C";
    orange = "#F76B15";
    pink = "#D6409F";
    purple = "#8E4EC6";
    red = "#E5484D";
    yellow = "#FFC53D";
  };

  # opencode's defaults for the guards a `"*"` deny would also switch off; Claude's allowlist never limits them.
  guardDefaults = {
    external_directory = "ask";
    doom_loop = "ask";
  };

  inherit (import ../../models.nix {inherit lib;}) targetForModel;

  # opencode reads a bare alias like `sonnet` as a provider name; dropping it inherits the session model.
  opencodeModel = model:
    if targetForModel model == "opencode"
    then model
    else null;

  reads = {
    agents = {
      description = always;
      prompt = always;
      model = model: opencodeModel model != null;
      reasoningEffort = always;
      maxTurns = always;
      color = always;
      tools = always;
      disallowedTools = always;
      "extra.opencode" = always;
    };
    commands = {
      description = always;
      agent = always;
      model = model: opencodeModel model != null;
      subtask = always;
      content = always;
      "extra.opencode" = always;
    };
    skills = {
      name = always;
      description = always;
      whenToUse = always;
      license = always;
      compatibility = always;
      metadata = always;
      invocation = always;
      version = always;
      paths = always;
      prompt = always;
      resourcesRoot = always;
      "extra.opencode" = always;
    };
    rules = {
      description = always;
      paths = always;
      content = always;
    };
    mcpServers = {
      type = always;
      command = always;
      args = always;
      env = always;
      cwd = always;
      url = always;
      headers = always;
      oauth = always;
      enabled = always;
      startupTimeout = always;
      "extra.opencode" = always;
    };
    lspServers = {
      command = always;
      args = always;
      env = always;
      extensionToLanguage = always;
      initializationOptions = always;
      enabled = always;
      "extra.opencode" = always;
    };
  };

  withExtra = withExtraFor "opencode";

  substituteSkillDir = name: lib.replaceStrings ["\${SKILL_DIR}"] ["${skillsDir}/${name}"];

  fallbackString = preferred: fallback:
    if preferred != null
    then preferred
    else fallback;

  # opencode names MCP tools `<server>_<tool>`; Claude's bare `mcp__<server>` means every tool.
  toolPermissionKey = tool: let
    mcp = builtins.match "mcp__([^_]+(_[^_]+)*)(__(.+))?" tool;
  in
    claudeToolPermissions.${
      tool
    } or (
      if mcp != null
      then "${lib.elemAt mcp 0}_${
        if lib.elemAt mcp 3 == null
        then "*"
        else lib.elemAt mcp 3
      }"
      else lib.toLower tool
    );

  permissionsFor = action: tools:
    lib.listToAttrs (map (tool: lib.nameValuePair (toolPermissionKey tool) action) tools);

  # Denies merge last so a tool both allowed and disallowed stays denied, as in Claude.
  agentPermission = agent: let
    permission =
      lib.optionalAttrs (agent.tools != []) ({"*" = "deny";} // guardDefaults // permissionsFor "allow" agent.tools)
      // permissionsFor "deny" agent.disallowedTools;
  in
    if permission == {}
    then null
    else permission;

  # FLAKE-UPDATE: unknown agent keys become provider options in opencode 1.19.0 (`v1/config/agent.ts`), which is where reasoningEffort belongs; after a bump, check it still does or map reasoningEffort explicitly.
  renderAgent = name: agent:
    frontmatter.toFile {
      attrs = withExtra agent {
        description = fallbackString agent.description name;
        mode = "subagent";
        model = opencodeModel agent.model;
        inherit (agent) reasoningEffort;
        steps = agent.maxTurns;
        color =
          if agent.color == null
          then null
          else agentColorHex.${agent.color};
        permission = agentPermission agent;
      };
      body = readContent agent.prompt;
    };

  renderCommand = command:
    frontmatter.toFile {
      attrs = withExtra command {
        inherit (command) description;
        inherit (command) agent;
        model = opencodeModel command.model;
        inherit (command) subtask;
      };
      body = readContent command.content;
    };

  skillText = name: skill: let
    promptBody = substituteSkillDir name (readContent skill.prompt);
    usageSection = lib.optional (skill.paths != []) "## Usage\nApplies to: ${lib.concatStringsSep ", " skill.paths}";
    body = lib.concatStringsSep "\n\n" (lib.filter (part: part != "") ([promptBody] ++ usageSection));
  in
    frontmatter.toFile {
      attrs = withExtra skill {
        inherit (skill) name;
        description = skillDescription skill;
        inherit (skill) license;
        compatibility = fallbackString skill.compatibility "opencode";
        metadata =
          skill.metadata
          // {
            "opencode/slash" = lib.boolToString skill.invocation.user;
          }
          // lib.optionalAttrs (!skill.invocation.model) {"opencode/autoinvoke" = "false";}
          // lib.optionalAttrs (skill.version != null) {inherit (skill) version;};
      };
      inherit body;
    };

  # A skill with resources is a whole directory, which programs.opencode.skills cannot take.
  renderSkill = name: skill:
    if skill.resourcesRoot != null
    then
      skillResources.mkSkillDir {
        inherit pkgs name;
        inherit (skill) resourcesRoot;
        tool = "opencode";
        skillMd = skillText name skill;
      }
    else skillText name skill;

  # opencode also scans ~/.agents/skills, where Codex writes commands as skills.
  # Manual-only skills stay allowed: `opencode/autoinvoke` hides them, and `deny` would block manual use too.
  hiddenSkills = skills: let
    names = lib.mapAttrsToList (_: skill: skill.name) skills;
  in
    lib.genAttrs (lib.subtractLists names codexSkillNames) (_: "deny");

  renderOauth = oauth:
    lib.filterAttrs (_: value: value != null) {
      inherit (oauth) clientId;
      inherit (oauth) callbackPort;
      scope =
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
            type = "remote";
            inherit (server) url;
          }
          // lib.optionalAttrs (server.headers != {}) {inherit (server) headers;}
          // lib.optionalAttrs (renderOauth server.oauth != {}) {oauth = renderOauth server.oauth;}
        else
          {
            type = "local";
            command = [server.command] ++ server.args;
          }
          // lib.optionalAttrs (server.env != {}) {environment = server.env;}
          // lib.optionalAttrs (server.cwd != null) {inherit (server) cwd;}
      )
      // lib.optionalAttrs (!server.enabled) {enabled = false;}
      // lib.optionalAttrs (server.startupTimeout != null) {timeout = server.startupTimeout;}
    );

  # A disabled entry may have no command: it can just switch off a built-in server.
  renderLspServer = server:
    withExtra server (
      if !server.enabled && server.command == null
      then {disabled = true;}
      else
        {
          command = [server.command] ++ server.args;
        }
        // lib.optionalAttrs (server.env != {}) {inherit (server) env;}
        // {extensions = lib.attrNames server.extensionToLanguage;}
        // lib.optionalAttrs (server.initializationOptions != {}) {initialization = server.initializationOptions;}
        // lib.optionalAttrs (!server.enabled) {disabled = true;}
    );

  renderPlugin = plugin:
    if lib.isPath plugin || lib.isDerivation plugin
    then {source = plugin;}
    else {text = plugin;};

  renderInstructions = profile: lib.concatStringsSep "\n\n" (inlinedSections profile);
  renderAgents = lib.mapAttrs renderAgent;
  renderSkills = skills: {
    definitions = lib.mapAttrs renderSkill skills;
    permission = hiddenSkills skills;
  };
  renderCommands = lib.mapAttrs (_: renderCommand);
  renderMcpServers = lib.mapAttrs (_: renderMcpServer);
  renderLspServers = lib.mapAttrs (_: renderLspServer);
  renderHooks = lib.mapAttrs (_: renderPlugin);
in
  profile: {
    instructions = renderInstructions profile;
    # opencode loads one context string, so rules are inlined into `instructions`.
    rules = {};
    agents = renderAgents profile.agents;
    skills = renderSkills profile.skills;
    commands = renderCommands profile.commands;
    mcpServers = renderMcpServers profile.mcpServers;
    lspServers = renderLspServers profile.lspServers;
    # opencode's hooks are its JS plugins, global rather than per profile.
    hooks = renderHooks plugins;
    dropped = droppedFields reads profile;
  }
