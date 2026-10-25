# The opencode target: what it renders from the shared profile model.
{
  harness,
  lib,
  pkgs,
  ...
}: let
  inherit (import ./_cases.nix {inherit harness lib pkgs;}) agentColors agentWithModel codexHookTargets evalTargets failedOf fixtureBody fixtureFile frontmatter hexColored invocationProfile invocationRendered lspRendered needleProblems noNeedleProblems opencodeAgents opencodeLsp opencodeMcp opencodeSkill optionalRendered permissionOf pluginConfig remoteMcp remoteMcpWithoutHeaders renderOpencodeWith renderedPlugins spec toOpencode typed;
in {
  "test opencode inlines an instructions source" = {
    expr = (toOpencode {instructions.source = fixtureFile;}).instructions;
    expected = fixtureBody;
  };
  "test opencode titles a path-scoped rule by name when it has no description" = {
    expr =
      (toOpencode {
        rules.comments = {
          paths = ["**/*.{ts,nix}"];
          content = spec "rule body";
        };
      }).instructions;
    expected = "## comments\n\nApplies to: **/*.{ts,nix}\n\nrule body";
  };
  "test opencode drops a bare model alias it would misread as a provider" = {
    expr = needleProblems (opencodeAgents {a = agentWithModel "sonnet";}).a {
      contains = ["mode: 'subagent'"];
      lacks = ["model:"];
    };
    expected = noNeedleProblems;
  };
  "test opencode keeps a provider-qualified model" = {
    expr = lib.hasInfix "model: 'ai-proxy/gpt-6-luna'" (opencodeAgents {a = agentWithModel "ai-proxy/gpt-6-luna";}).a;
    expected = true;
  };
  "test an xhigh effort is accepted and reaches opencode" = {
    expr = lib.hasInfix "reasoningEffort: 'xhigh'" (opencodeAgents {a = (agentWithModel null) // {reasoningEffort = "xhigh";};}).a;
    expected = true;
  };
  "test an ultra effort is accepted and reaches opencode" = {
    expr = lib.hasInfix "reasoningEffort: 'ultra'" (opencodeAgents {a = (agentWithModel null) // {reasoningEffort = "ultra";};}).a;
    expected = true;
  };
  "test opencode keeps a manual-only skill out of auto-invocation" = {
    expr = lib.hasInfix "opencode/autoinvoke: 'false'" (opencodeSkill "manual");
    expected = true;
  };
  "test opencode drops the manual-only prose line" = {
    expr = needleProblems (opencodeSkill "manual") {
      contains = ["manual body"];
      lacks = ["Manual invocation only."];
    };
    expected = noNeedleProblems;
  };
  "test opencode offers a user-invocable skill as a slash command" = {
    expr = lib.hasInfix "opencode/slash: 'true'" (opencodeSkill "manual");
    expected = true;
  };
  "test opencode keeps a background skill off the slash menu" = {
    expr = lib.hasInfix "opencode/slash: 'false'" (opencodeSkill "background");
    expected = true;
  };
  "test opencode drops the background-skill prose line" = {
    expr = needleProblems (opencodeSkill "background") {
      contains = ["background body"];
      lacks = ["Background skill"];
    };
    expected = noNeedleProblems;
  };
  "test opencode leaves a model-invocable skill auto-invocable" = {
    expr = needleProblems (opencodeSkill "background") {
      contains = ["opencode/slash: 'false'"];
      lacks = ["autoinvoke"];
    };
    expected = noNeedleProblems;
  };
  "test opencode nests a skill's version under metadata" = {
    expr = lib.hasInfix "\n  version: '1.2'" (opencodeSkill "versioned");
    expected = true;
  };
  "test opencode emits no skill fields its frontmatter ignores" = {
    expr = needleProblems (opencodeSkill "versioned") {
      contains = ["name: 'versioned'" "versioned body"];
      lacks = ["\nversion:" "model:" "context:" "agent:"];
    };
    expected = noNeedleProblems;
  };
  "test opencode writes only declared commands, not copies of skills" = {
    expr = lib.attrNames invocationRendered.commands;
    expected = ["commit" "shared"];
  };
  "test opencode hides the skills Codex renders from commands but not agents, which Codex renders as subagents" = {
    expr = invocationProfile.programs.opencode.settings.permission.skill;
    expected = {
      commit = "deny";
    };
  };
  "test opencode hides nothing when every Codex skill is also its own" = {
    expr = (evalTargets {skills.s = {prompt = spec "s";};}).programs.opencode.settings ? permission;
    expected = false;
  };
  "test opencode denies every tool an agent's allowlist leaves out" = {
    expr = lib.hasInfix "permission:\n  '*': 'deny'" (permissionOf {tools = ["Read"];});
    expected = true;
  };
  "test opencode maps Claude's Write and Edit onto its edit permission" = {
    expr = map (key: lib.hasInfix "  ${key}: 'allow'" (permissionOf {tools = ["Read" "Write" "Edit"];})) ["edit" "read"];
    expected = [true true];
  };
  "test opencode maps Claude's Agent tool onto task" = {
    expr = lib.hasInfix "  task: 'allow'" (permissionOf {tools = ["Agent"];});
    expected = true;
  };
  "test opencode maps a Claude MCP tool onto its server_tool name" = {
    expr = lib.hasInfix "  sqry_direct_callers: 'allow'" (permissionOf {tools = ["mcp__sqry__direct_callers"];});
    expected = true;
  };
  "test opencode maps a bare Claude MCP server onto all of its tools" = {
    expr = lib.hasInfix "  'my_mcp_*': 'deny'" (permissionOf {disallowedTools = ["mcp__my_mcp"];});
    expected = true;
  };
  "test opencode keeps the external-directory and doom-loop guards at their ask default under a tool allowlist" = {
    expr = map (key: lib.hasInfix "  ${key}: 'ask'" (permissionOf {tools = ["Read"];})) ["doom_loop" "external_directory"];
    expected = [true true];
  };
  "test opencode keeps a tool denied when it is also allowed" = {
    expr = lib.hasInfix "  bash: 'deny'" (permissionOf {
      tools = ["Bash"];
      disallowedTools = ["Bash"];
    });
    expected = true;
  };
  "test opencode maps a disallowed Claude tool without a wildcard deny" = {
    expr = lib.hasInfix "permission:\n  edit: 'deny'\n" (permissionOf {disallowedTools = ["Write"];});
    expected = true;
  };
  "test an agent with no tool limits gets no opencode permission map" = {
    expr = needleProblems (permissionOf {}) {
      contains = ["mode: 'subagent'"];
      lacks = ["permission"];
    };
    expected = noNeedleProblems;
  };
  "test a wildcard frontmatter key is quoted so YAML does not read an alias" = {
    expr = frontmatter.toFile {attrs.p."*" = "deny";};
    expected = "---\np:\n  '*': 'deny'\n---\n\n";
  };
  "test opencode passes remote MCP headers through" = {
    expr = remoteMcp.headers;
    expected = {Authorization = "Bearer t";};
  };
  "test opencode omits headers a remote MCP server does not set" = {
    expr = remoteMcpWithoutHeaders ? headers;
    expected = false;
  };
  "test opencode lists an LSP server's extensions" = {
    expr = lspRendered.lspServers.l.extensions;
    expected = [".l"];
  };
  "test opencode writes each plugin as its own file under opencode/plugins" = {
    expr = lib.filter (lib.hasPrefix "opencode/plugins/") (lib.attrNames pluginConfig.xdg.configFile);
    expected = ["opencode/plugins/guard.ts" "opencode/plugins/notify.js"];
  };
  "test opencode writes an inline plugin as text and a path plugin as a link" = {
    expr = [renderedPlugins."notify.js" renderedPlugins."guard.ts"];
    expected = [{text = "export const Notify = async () => ({})";} {source = ../../../tests/fixtures/clean/reference.md;}];
  };
  "test a plugin name opencode would not load fails an assertion" = {
    expr = failedOf (codexHookTargets {} {notify = "x";});
    expected = ["programs.code-assistant-profiles.targets.opencode.plugins.\"notify\" must end in .js or .ts; opencode loads only those from opencode/plugins/"];
  };
  "test opencode maps a local server's cwd, startup timeout and disabled state, then merges extra" = {
    expr = opencodeMcp.local;
    expected = {
      type = "local";
      command = ["srv"];
      cwd = "/srv";
      enabled = false;
      timeout = 20000;
      environment.EXTRA = "1";
    };
  };
  "test opencode maps a remote server's oauth with scopes space-joined and drops the headers helper" = {
    expr = opencodeMcp.remote;
    expected = {
      type = "remote";
      url = "https://mcp.example";
      oauth = {
        clientId = "cid";
        callbackPort = 8080;
        scope = "read write";
      };
    };
  };
  "test opencode sends initializationOptions as initialization and merges LSP extra" = {
    expr = opencodeLsp.l;
    expected = {
      command = ["l"];
      extensions = [".l"];
      initialization.formatting = true;
      env.LSP = "1";
    };
  };
  "test opencode switches off a built-in LSP server with no command" = {
    expr = opencodeLsp.typescript;
    expected = {disabled = true;};
  };
  "test opencode keeps a disabled LSP server's definition" = {
    expr = opencodeLsp.muted.disabled;
    expected = true;
  };
  "test opencode gets a hex value for a Claude color name" = {
    expr = lib.hasInfix "color: '#E5484D'" optionalRendered.agents.painter;
    expected = true;
  };
  "test opencode gets a hex value for every shared color name" = {
    expr = hexColored;
    expected = map (_: true) agentColors;
  };
  "test opencode merges agent extra last, overriding the subagent mode" = {
    expr = map (line: lib.hasInfix line optionalRendered.agents.painter) ["mode: 'primary'" "temperature: 0.200000"];
    expected = [true true];
  };
  "test opencode passes a command's agent, subtask and extra" = {
    expr = map (line: lib.hasInfix line optionalRendered.commands.ship) ["agent: 'build'" "subtask: true" "variant: 'high'"];
    expected = [true true true];
  };
  "test opencode drops a command's bare model alias" = {
    expr = needleProblems optionalRendered.commands.ship {
      contains = ["agent: 'build'" "ship body"];
      lacks = ["model"];
    };
    expected = noNeedleProblems;
  };
  "test opencode keeps a command's provider-qualified model" = {
    expr = lib.hasInfix "model: 'ai-proxy/gpt-6-luna'" optionalRendered.commands.qualified;
    expected = true;
  };
  "test opencode emits a skill's license and metadata beside its own keys" = {
    expr = map (line: lib.hasInfix line optionalRendered.skills.definitions.licensed) ["license: 'MIT'" "  short-description: 'Short'" "  opencode/slash: 'true'"];
    expected = [true true true];
  };
  "test opencode skill extra overrides the default compatibility" = {
    expr = lib.hasInfix "compatibility: 'opencode >= 1.19'" optionalRendered.skills.definitions.licensed;
    expected = true;
  };
  "test opencode reports an agent's unread fields and bare model alias as dropped" = {
    expr =
      (toOpencode {
        agents.a = {
          prompt = spec "a";
          model = "sonnet";
          skills = ["s"];
          category = "review";
          tools = ["Read"];
        };
      }).dropped;
    expected = {agents.a = ["category" "model" "skills"];};
  };
  "test opencode keeps only provider-qualified models and reports the rest" = {
    expr =
      (toOpencode {
        agents = lib.mapAttrs (_: agentWithModel) {
          claude = "opus[1m]";
          openai = "gpt-5";
          qualified = "anthropic/claude-opus-4-6";
        };
      }).dropped.agents;
    expected = {
      claude = ["model"];
      openai = ["model"];
    };
  };
  "test opencode reports nothing for an LSP server it expresses whole" = {
    expr = lspRendered.dropped;
    expected = {};
  };
  "test opencode hides the Codex skill names it does not define but leaves a manual-only skill allowed" = {
    expr =
      (renderOpencodeWith {codexSkillNames = ["commit" "s"];} (typed {
        skills.s.prompt = spec "s";
        skills.m = {
          prompt = spec "m";
          invocation.model = false;
        };
      })).skills.permission;
    expected = {
      commit = "deny";
    };
  };
}
