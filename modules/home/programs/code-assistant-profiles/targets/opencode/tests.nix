# The opencode target.
{
  pkgs,
  lib,
  ...
}: let
  inherit (import ../../tests/fixtures.nix {inherit pkgs lib;}) agentWithModel codexHookTargets evalTargets expect expectText failedOf fixtureBody fixtureFile frontmatter invocationConfig invocationProfile libWithCustom optionalFieldsConfig spec typed;

  renderOpencodeWith = {
    codexSkillNames ? [],
    plugins ? {},
  }:
    import ./render.nix {
      inherit codexSkillNames pkgs plugins;
      lib = libWithCustom;
      customLib = libWithCustom.custom;
      skillsDir = "/home/t/.config/opencode/skills";
    };

  toOpencode = raw: renderOpencodeWith {} (typed raw);

  opencodeAgents = agents: (toOpencode {inherit agents;}).agents;
  inherit (import ../../options/fields.nix {inherit lib;}) agentColors;
  hexColored = map (color: builtins.match ".*color: '#[0-9A-F]{6}'.*" (opencodeAgents {a = (agentWithModel null) // {inherit color;};}).a != null) agentColors;
  remoteMcp =
    (toOpencode {
      mcpServers.r = {
        type = "remote";
        url = "https://mcp.example";
        headers.Authorization = "Bearer t";
      };
    }).mcpServers.r;
  remoteMcpWithoutHeaders =
    (toOpencode {
      mcpServers.r = {
        type = "remote";
        url = "https://mcp.example";
      };
    }).mcpServers.r;
  lspRendered = toOpencode {
    lspServers.l = {
      command = "l";
      extensionToLanguage.".l" = "l";
    };
  };

  invocationRendered = toOpencode invocationConfig;
  opencodeSkill = name: invocationRendered.skills.definitions.${name};
  permissionOf = agent: (opencodeAgents {a = (agentWithModel null) // agent;}).a;

  optionalRendered = toOpencode optionalFieldsConfig;
  opencodeMcp = optionalRendered.mcpServers;
  opencodeLsp = optionalRendered.lspServers;
  plugins = {
    "notify.js" = "export const Notify = async () => ({})";
    "guard.ts" = ../../tests/fixtures/clean/reference.md;
  };
  pluginConfig = codexHookTargets {} plugins;
  renderedPlugins = (renderOpencodeWith {inherit plugins;} (typed {})).hooks;
in
  pkgs.runCommand "code-assistant-profiles-opencode-test" {} ''
    ${expect "opencode inlines an instructions source" (toOpencode {instructions.source = fixtureFile;}).instructions fixtureBody}
    ${expect "opencode titles a path-scoped rule by name when it has no description"
      (toOpencode {
        rules.comments = {
          paths = ["**/*.{ts,nix}"];
          content = spec "rule body";
        };
      }).instructions "## comments\n\nApplies to: **/*.{ts,nix}\n\nrule body"}
    ${expectText "opencode drops a bare model alias it would misread as a provider" (opencodeAgents {a = agentWithModel "sonnet";}).a {
      contains = ["mode: 'subagent'"];
      lacks = ["model:"];
    }}
    ${expect "opencode keeps a provider-qualified model" (lib.hasInfix "model: 'ai-proxy/gpt-6-luna'" (opencodeAgents {a = agentWithModel "ai-proxy/gpt-6-luna";}).a) true}
    ${expect "an xhigh effort is accepted and reaches opencode" (lib.hasInfix "reasoningEffort: 'xhigh'" (opencodeAgents {a = (agentWithModel null) // {reasoningEffort = "xhigh";};}).a) true}
    ${expect "an ultra effort is accepted and reaches opencode" (lib.hasInfix "reasoningEffort: 'ultra'" (opencodeAgents {a = (agentWithModel null) // {reasoningEffort = "ultra";};}).a) true}
    ${expect "opencode keeps a manual-only skill out of auto-invocation" (lib.hasInfix "opencode/autoinvoke: 'false'" (opencodeSkill "manual")) true}
    ${expectText "opencode drops the manual-only prose line" (opencodeSkill "manual") {
      contains = ["manual body"];
      lacks = ["Manual invocation only."];
    }}
    ${expect "opencode offers a user-invocable skill as a slash command" (lib.hasInfix "opencode/slash: 'true'" (opencodeSkill "manual")) true}
    ${expect "opencode keeps a background skill off the slash menu" (lib.hasInfix "opencode/slash: 'false'" (opencodeSkill "background")) true}
    ${expectText "opencode drops the background-skill prose line" (opencodeSkill "background") {
      contains = ["background body"];
      lacks = ["Background skill"];
    }}
    ${expectText "opencode leaves a model-invocable skill auto-invocable" (opencodeSkill "background") {
      contains = ["opencode/slash: 'false'"];
      lacks = ["autoinvoke"];
    }}
    ${expect "opencode nests a skill's version under metadata" (lib.hasInfix "\n  version: '1.2'" (opencodeSkill "versioned")) true}
    ${expectText "opencode emits no skill fields its frontmatter ignores" (opencodeSkill "versioned") {
      contains = ["name: 'versioned'" "versioned body"];
      lacks = ["\nversion:" "model:" "context:" "agent:"];
    }}
    ${expect "opencode writes only declared commands, not copies of skills" (lib.attrNames invocationRendered.commands) ["commit" "shared"]}
    ${expect "opencode hides the skills Codex renders from commands but not agents, which Codex renders as subagents" invocationProfile.programs.opencode.settings.permission.skill {
      commit = "deny";
      manual = "deny";
    }}
    ${expect "opencode hides nothing when every Codex skill is also its own" ((evalTargets {skills.s = {prompt = spec "s";};}).programs.opencode.settings ? permission) false}
    ${expect "opencode denies every tool an agent's allowlist leaves out" (lib.hasInfix "permission:\n  '*': 'deny'" (permissionOf {tools = ["Read"];})) true}
    ${expect "opencode maps Claude's Write and Edit onto its edit permission" (map (key: lib.hasInfix "  ${key}: 'allow'" (permissionOf {tools = ["Read" "Write" "Edit"];})) ["edit" "read"]) [true true]}
    ${expect "opencode maps Claude's Agent tool onto task" (lib.hasInfix "  task: 'allow'" (permissionOf {tools = ["Agent"];})) true}
    ${expect "opencode maps a Claude MCP tool onto its server_tool name" (lib.hasInfix "  sqry_direct_callers: 'allow'" (permissionOf {tools = ["mcp__sqry__direct_callers"];})) true}
    ${expect "opencode maps a bare Claude MCP server onto all of its tools" (lib.hasInfix "  'my_mcp_*': 'deny'" (permissionOf {disallowedTools = ["mcp__my_mcp"];})) true}
    ${expect "opencode keeps the external-directory and doom-loop guards at their ask default under a tool allowlist" (map (key: lib.hasInfix "  ${key}: 'ask'" (permissionOf {tools = ["Read"];})) ["doom_loop" "external_directory"]) [true true]}
    ${expect "opencode keeps a tool denied when it is also allowed" (lib.hasInfix "  bash: 'deny'" (permissionOf {
        tools = ["Bash"];
        disallowedTools = ["Bash"];
      }))
      true}
    ${expect "opencode maps a disallowed Claude tool without a wildcard deny" (lib.hasInfix "permission:\n  edit: 'deny'\n" (permissionOf {disallowedTools = ["Write"];})) true}
    ${expectText "an agent with no tool limits gets no opencode permission map" (permissionOf {}) {
      contains = ["mode: 'subagent'"];
      lacks = ["permission"];
    }}
    ${expect "a wildcard frontmatter key is quoted so YAML does not read an alias" (frontmatter.toFile {attrs.p."*" = "deny";}) "---\np:\n  '*': 'deny'\n---\n\n"}
    ${expect "opencode passes remote MCP headers through" remoteMcp.headers {Authorization = "Bearer t";}}
    ${expect "opencode omits headers a remote MCP server does not set" (remoteMcpWithoutHeaders ? headers) false}
    ${expect "opencode lists an LSP server's extensions" lspRendered.lspServers.l.extensions [".l"]}
    ${expect "opencode writes each plugin as its own file under opencode/plugins" (lib.filter (lib.hasPrefix "opencode/plugins/") (lib.attrNames pluginConfig.xdg.configFile)) ["opencode/plugins/guard.ts" "opencode/plugins/notify.js"]}
    ${expect "opencode writes an inline plugin as text and a path plugin as a link" [renderedPlugins."notify.js" renderedPlugins."guard.ts"] [{text = "export const Notify = async () => ({})";} {source = ../../tests/fixtures/clean/reference.md;}]}
    ${expect "a plugin name opencode would not load fails an assertion" (failedOf (codexHookTargets {} {notify = "x";})) ["programs.code-assistant-profiles.targets.opencode.plugins.\"notify\" must end in .js or .ts; opencode loads only those from opencode/plugins/"]}

    ${expect "opencode maps a local server's cwd, startup timeout and disabled state, then merges extra" opencodeMcp.local {
      type = "local";
      command = ["srv"];
      cwd = "/srv";
      enabled = false;
      timeout = 20000;
      environment.EXTRA = "1";
    }}
    ${expect "opencode maps a remote server's oauth with scopes space-joined and drops the headers helper" opencodeMcp.remote {
      type = "remote";
      url = "https://mcp.example";
      oauth = {
        clientId = "cid";
        callbackPort = 8080;
        scope = "read write";
      };
    }}
    ${expect "opencode sends initializationOptions as initialization and merges LSP extra" opencodeLsp.l {
      command = ["l"];
      extensions = [".l"];
      initialization.formatting = true;
      env.LSP = "1";
    }}
    ${expect "opencode switches off a built-in LSP server with no command" opencodeLsp.typescript {disabled = true;}}
    ${expect "opencode keeps a disabled LSP server's definition" opencodeLsp.muted.disabled true}
    ${expect "opencode gets a hex value for a Claude color name" (lib.hasInfix "color: '#E5484D'" optionalRendered.agents.painter) true}
    ${expect "opencode gets a hex value for every shared color name" hexColored (map (_: true) agentColors)}
    ${expect "opencode merges agent extra last, overriding the subagent mode" (map (line: lib.hasInfix line optionalRendered.agents.painter) ["mode: 'primary'" "temperature: 0.200000"]) [true true]}
    ${expect "opencode passes a command's agent, subtask and extra" (map (line: lib.hasInfix line optionalRendered.commands.ship) ["agent: 'build'" "subtask: true" "variant: 'high'"]) [true true true]}
    ${expectText "opencode drops a command's bare model alias" optionalRendered.commands.ship {
      contains = ["agent: 'build'" "ship body"];
      lacks = ["model"];
    }}
    ${expect "opencode keeps a command's provider-qualified model" (lib.hasInfix "model: 'ai-proxy/gpt-6-luna'" optionalRendered.commands.qualified) true}
    ${expect "opencode emits a skill's license and metadata beside its own keys" (map (line: lib.hasInfix line optionalRendered.skills.definitions.licensed) ["license: 'MIT'" "  short-description: 'Short'" "  opencode/slash: 'true'"]) [true true true]}
    ${expect "opencode skill extra overrides the default compatibility" (lib.hasInfix "compatibility: 'opencode >= 1.19'" optionalRendered.skills.definitions.licensed) true}

    ${expect "opencode reports an agent's unread fields and bare model alias as dropped"
      (toOpencode {
        agents.a = {
          prompt = spec "a";
          model = "sonnet";
          skills = ["s"];
          category = "review";
          tools = ["Read"];
        };
      }).dropped {agents.a = ["category" "model" "skills"];}}
    ${expect "opencode reports nothing for an LSP server it expresses whole" lspRendered.dropped {}}
    ${expect "opencode hides a manual-only skill and the Codex skill names it does not define"
      (renderOpencodeWith {codexSkillNames = ["commit" "s"];} (typed {
        skills.s.prompt = spec "s";
        skills.m = {
          prompt = spec "m";
          invocation.model = false;
        };
      })).skills.permission {
        commit = "deny";
        m = "deny";
      }}

    echo "code-assistant-profiles: opencode target checks OK"
    touch "$out"
  ''
