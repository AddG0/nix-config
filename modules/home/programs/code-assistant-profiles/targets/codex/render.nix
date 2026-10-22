# A resolved shared profile, rendered into Codex's artefacts; with `base`, only what a profile file layers over it.
{
  base ? null,
  checkAgent,
  codexHooks,
  customLib,
  hooks,
  lib,
  pkgs,
  skillsDir,
}: let
  inherit (customLib) frontmatter;
  skillResources = import ../../skill-resources.nix {inherit lib;};
  inherit (import ../../content.nix {inherit lib;}) always droppedFields inlineRule inlinedSections readContent skillDescription withExtraFor;

  inherit (import ../../models.nix {inherit lib;}) targetForModel;

  # An agent file cannot switch model_provider, so only a bare OpenAI model routes.
  codexModel = model:
    if targetForModel model == "codex"
    then model
    else null;

  # Codex reads only name, description and metadata.short-description from SKILL.md; the rest lives in agents/openai.yaml.
  skillMetadataKeys = ["short-description"];

  millisecondsPerSecond = 1000.0;

  reads = {
    agents = {
      description = always;
      prompt = always;
      model = model: codexModel model != null;
      reasoningEffort = always;
      "extra.codex" = always;
    };
    commands = {
      description = always;
      content = always;
      "extra.codex" = always;
    };
    skills = {
      name = always;
      description = always;
      whenToUse = always;
      metadata = metadata: lib.subtractLists skillMetadataKeys (lib.attrNames metadata) == [];
      invocation = invocation: invocation.user;
      prompt = always;
      resourcesRoot = always;
      "extra.codex" = always;
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
      headersHelper = always;
      oauth = always;
      enabled = always;
      startupTimeout = always;
      toolTimeout = always;
      "extra.codex" = always;
    };
    # Codex has no LSP client.
    lspServers = {};
  };

  tomlFormat = pkgs.formats.toml {};

  withExtra = withExtraFor "codex";

  fallbackString = preferred: fallback:
    if preferred != null
    then preferred
    else fallback;

  substituteSkillDir = name: lib.replaceStrings ["\${SKILL_DIR}"] ["${skillsDir}/${name}"];

  skillFrontmatter = skill:
    {
      inherit (skill) name;
      description = skillDescription skill;
    }
    // lib.optionalAttrs (skill.metadata ? "short-description") {metadata."short-description" = skill.metadata."short-description";};

  # Implicit invocation defaults to allowed, so only a manual-only skill or one with extras needs the file.
  skillPolicyText = skill: let
    policy = lib.recursiveUpdate (lib.optionalAttrs (!skill.invocation.model) {policy.allow_implicit_invocation = false;}) skill.extra.codex;
  in
    if policy == {}
    then null
    else lib.generators.toYAML {} policy;

  skillText = name: skill:
    frontmatter.toFile {
      attrs = skillFrontmatter skill;
      body = substituteSkillDir name (readContent skill.prompt);
    };

  skillDirectory = name: skill: let
    policy = skillPolicyText skill;
  in
    skillResources.mkSkillDir {
      inherit pkgs name;
      inherit (skill) resourcesRoot;
      tool = "codex";
      skillMd = skillText name skill;
      extraCommands = lib.optionalString (policy != null) ''
        if [ -e "$out/agents/openai.yaml" ]; then
          printf '%s\n' ${lib.escapeShellArg "codex skill '${name}' resourcesRoot must not contain agents/openai.yaml; it is generated from skill.invocation.model and extra.codex"} >&2
          exit 1
        fi
        mkdir -p "$out/agents"
        cat > "$out/agents/openai.yaml" <<'EOF'
        ${policy}
        EOF
      '';
    };

  # One linked directory per skill, never the root, which other tools write into: Codex skips a symlinked SKILL.md.
  renderSkill = dir: skill: {${dir}.source = skillDirectory dir skill;};

  # Commands surface as user-invocable skills since ~/.codex/prompts/ is deprecated.
  commandSkill = name: command: {
    inherit name;
    inherit (command) description extra;
    prompt = command.content;
    whenToUse = null;
    metadata = {};
    invocation.model = true;
    resourcesRoot = null;
  };

  renderAgent = name: agent:
    checkAgent name (tomlFormat.generate "codex-agent-${lib.strings.sanitizeDerivationName name}.toml" (withExtra agent (lib.filterAttrs (_: value: value != null) {
      inherit name;
      description = fallbackString agent.description name;
      developer_instructions = readContent agent.prompt;
      model = codexModel agent.model;
      model_reasoning_effort = agent.reasoningEffort;
    })));

  renderOauth = oauth:
    lib.filterAttrs (_: value: value != null) {
      client_id = oauth.clientId;
      callback_port = oauth.callbackPort;
    };

  renderMcpServer = server:
    withExtra server (
      (
        if server.type == "remote"
        then
          {inherit (server) url;}
          // lib.optionalAttrs (server.headers != {}) {http_headers = server.headers;}
          // lib.optionalAttrs (server.headersHelper != null) {http_headers_helper = server.headersHelper;}
          // lib.optionalAttrs (renderOauth server.oauth != {}) {oauth = renderOauth server.oauth;}
          // lib.optionalAttrs (server.oauth.scopes != []) {inherit (server.oauth) scopes;}
        else
          {inherit (server) command;}
          // lib.optionalAttrs (server.args != []) {inherit (server) args;}
          // lib.optionalAttrs (server.env != {}) {inherit (server) env;}
          // lib.optionalAttrs (server.cwd != null) {inherit (server) cwd;}
      )
      // lib.optionalAttrs (!server.enabled) {enabled = false;}
      // lib.optionalAttrs (server.startupTimeout != null) {startup_timeout_ms = server.startupTimeout;}
      // lib.optionalAttrs (server.toolTimeout != null) {tool_timeout_sec = server.toolTimeout / millisecondsPerSecond;}
    );

  allMcpServers = profile: lib.mapAttrs (_: renderMcpServer) profile.mcpServers;

  notIn = sections: lib.filter (section: !(builtins.elem section sections));

  # A profile file layers over config.toml and AGENTS.md, so it holds only what differs from `base`.
  renderInstructions = profile:
    lib.concatStringsSep "\n\n" (
      if base == null
      then inlinedSections profile
      else
        notIn base.instructionSections profile.instructionSections
        ++ notIn (lib.mapAttrsToList inlineRule base.rules) (lib.mapAttrsToList inlineRule profile.rules)
    );

  renderMcpServers = profile: let
    servers = allMcpServers profile;
    baseServers = allMcpServers base;
  in
    if base == null
    then servers
    else
      lib.filterAttrs (name: server: baseServers.${name} or null != server) servers
      // lib.mapAttrs (_: _: {enabled = false;}) (removeAttrs baseServers (lib.attrNames servers));

  # Precedence on a name clash: the skill, then the command.
  commandSkills = profile: lib.mapAttrs commandSkill (removeAttrs profile.commands (lib.attrNames profile.skills));
  renderCommands = profile: lib.concatMapAttrs renderSkill (commandSkills profile);
  renderSkills = profile: lib.concatMapAttrs renderSkill profile.skills;
  renderAgents = profile: lib.mapAttrs' (name: agent: lib.nameValuePair "${name}.toml" {source = renderAgent name agent;}) profile.agents;

  # Skills, agents, commands and hooks are global, so a layered profile file carries none.
  globalOnly = rendered:
    if base == null
    then rendered
    else {};
in
  profile: {
    instructions = renderInstructions profile;
    # Codex loads one AGENTS.md, so rules are inlined into `instructions`.
    rules = {};
    agents = globalOnly (renderAgents profile);
    skills = globalOnly (renderSkills profile);
    commands = globalOnly (renderCommands profile);
    # A skill or command's files in another directory, keeping its name: how a profile's own copy sits beside the default's.
    skillIn = dir: name: renderSkill dir (commandSkills profile // profile.skills).${name};
    mcpServers = renderMcpServers profile;
    lspServers = {};
    hooks = globalOnly (codexHooks.render hooks);
    dropped = droppedFields reads profile;
  }
