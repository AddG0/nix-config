# The claude-code target: what it renders from the shared profile model.
{
  harness,
  lib,
  pkgs,
  ...
}: let
  inherit (import ./_cases.nix {inherit harness lib pkgs;}) claudeAgentWith claudeExtras claudeRendered claudeTargetConfig claudeTargetHookProblems codexHooked failedOf frontmatterHooks hookMessages forced javaLike misspelledAgentHook modelsOfEveryProvider needleProblems noNeedleProblems profile renderedPassthroughAgent ruleWithExtra sourceSpec toClaude;
in {
  "test claude-code passes an instructions source through unread" = {
    expr = claudeRendered.instructions;
    expected = sourceSpec;
  };
  "test claude-code drops the effort level it has no name for" = {
    expr = needleProblems claudeRendered.agents.demo {
      contains = ["description: 'A demo agent'"];
      lacks = ["effort"];
    };
    expected = noNeedleProblems;
  };
  "test claude-code drops an ultra effort it has no name for" = {
    expr = needleProblems (toClaude (profile {agents.demo = claudeAgentWith {reasoningEffort = "ultra";};})).agents.demo {
      contains = ["description: 'A demo agent'"];
      lacks = ["effort"];
    };
    expected = noNeedleProblems;
  };
  "test claude-code emits an agent's declared tools" = {
    expr = lib.hasInfix "  - 'Read'" claudeRendered.agents.demo;
    expected = true;
  };
  "test a rule with no paths renders as its bare source" = {
    expr = claudeRendered.rules.plain;
    expected = "plain body";
  };
  "test claude-code omits the agent category it does not read" = {
    expr = needleProblems claudeRendered.agents.demo {
      contains = ["name: 'demo'"];
      lacks = ["category"];
    };
    expected = noNeedleProblems;
  };
  "test claude-code nests a skill's version under metadata" = {
    expr = lib.hasInfix "metadata:\n  version: '1.2'" claudeRendered.skills.versioned;
    expected = true;
  };
  "test claude-code emits no top-level skill version" = {
    expr = needleProblems claudeRendered.skills.versioned {
      contains = ["metadata:\n  version: '1.2'"];
      lacks = ["\nversion:"];
    };
    expected = noNeedleProblems;
  };
  "test claude-code emits an LSP server's extension map" = {
    expr =
      (toClaude (profile {
        lspServers.l = {
          command = "l";
          args = [];
          env = {};
          extensionToLanguage.".l" = "l";
        };
      })).lspServers.l.extensionToLanguage;
    expected = {".l" = "l";};
  };
  "test claude-code leaves a disabled MCP server out" = {
    expr = lib.attrNames claudeExtras.mcpServers;
    expected = ["remote" "sse"];
  };
  "test claude-code maps a remote server's tool timeout, headers helper and oauth, scopes space-joined" = {
    expr = claudeExtras.mcpServers.remote;
    expected = {
      type = "http";
      url = "https://mcp.example";
      headersHelper = "print-headers";
      timeout = 30000;
      oauth = {
        clientId = "cid";
        callbackPort = 8080;
        scopes = "read write";
      };
    };
  };
  "test claude-code merges MCP extra last, overriding the transport and keeping sibling oauth fields" = {
    expr = with claudeExtras.mcpServers.sse; [type oauth.clientId oauth.authServerMetadataUrl];
    expected = ["sse" "cid" "https://auth.example/meta"];
  };
  "test claude-code leaves a disabled LSP server out" = {
    expr = lib.attrNames claudeExtras.lspServers;
    expected = ["l"];
  };
  "test claude-code passes an LSP server's initializationOptions" = {
    expr = claudeExtras.lspServers.l.initializationOptions;
    expected = {formatting = true;};
  };
  "test claude-code passes a Claude color name through" = {
    expr = lib.hasInfix "color: 'cyan'" claudeExtras.agents.demo;
    expected = true;
  };
  "test claude-code merges agent extra fields into the frontmatter" = {
    expr = map (line: lib.hasInfix line claudeExtras.agents.demo) ["permissionMode: 'plan'" "isolation: 'worktree'"];
    expected = [true true];
  };
  "test an agent's extra overrides the field the shared layer rendered" = {
    expr = lib.hasInfix "tools:\n  - 'Grep'\n" claudeExtras.agents.demo;
    expected = true;
  };
  "test claude-code renders nested agent hooks from extra as YAML, not inline JSON" = {
    expr = lib.hasInfix "hooks:\n  PreToolUse:\n    - hooks:\n        - command: 'guard'\n          type: 'command'\n      matcher: 'Bash'\n" claudeExtras.agents.demo;
    expected = true;
  };
  "test claude-code forks a subtask command and passes its model, agent and extra" = {
    expr = map (line: lib.hasInfix line claudeExtras.commands.ship) ["context: 'fork'" "model: 'opus'" "agent: 'Explore'" "effort: 'high'"];
    expected = [true true true true];
  };
  "test claude-code emits a skill's license, compatibility and metadata beside its version" = {
    expr = map (line: lib.hasInfix line claudeExtras.skills.licensed) ["license: 'MIT'" "compatibility: 'needs git'" "metadata:\n  owner: 'addg'\n  version: '1.2'"];
    expected = [true true true];
  };
  "test claude-code merges skill extra into the frontmatter" = {
    expr = lib.hasInfix "arguments:\n  - 'issue'\n  - 'branch'" claudeExtras.skills.licensed;
    expected = true;
  };
  "test a passthrough boolean renders unquoted in the agent frontmatter" = {
    expr = map (line: lib.hasInfix line renderedPassthroughAgent) ["background: true\n" "memory: 'project'\n" "count: 3\n"];
    expected = [true true true];
  };
  "test claude-code renders typed agent frontmatter hooks without unset fields" = {
    expr = lib.hasInfix "hooks:\n  Stop:\n    - hooks:\n        - command: 'check'\n          timeout: 5\n          type: 'command'\n" frontmatterHooks.agents.guarded;
    expected = true;
  };
  "test claude-code keeps once on a skill frontmatter hook" = {
    expr = lib.hasInfix "hooks:\n  PostToolUse:\n    - hooks:\n        - command: 'fmt'\n          once: true\n          type: 'command'\n      matcher: 'Edit'\n" frontmatterHooks.skills.formatted;
    expected = true;
  };
  "test a misspelled event in agent frontmatter hooks fails evaluation" = {
    expr = forced misspelledAgentHook;
    expectedError.type = "ThrownError";
    expectedError.msg = "hooks\\.PreToolUs' does not exist";
  };
  "test once in agent frontmatter hooks fails an assertion, but not in skill frontmatter" = {
    expr = hookMessages;
    expected = ["profile 'p' agent 'a' extra.claude-code.hooks: Stop[0].hooks[0] (type command) sets `once`, which Claude Code honours only in skill frontmatter"];
  };
  "test the claude-code target enables claude-code-profiles" = {
    expr = claudeTargetConfig.programs.claude-code-profiles.enable;
    expected = true;
  };
  "test the claude-code target renders each resolved profile into profileDefaults" = {
    expr = lib.attrNames claudeTargetConfig.programs.claude-code-profiles.profileDefaults;
    expected = ["default"];
  };
  "test the claude-code target renders a profile's rules" = {
    expr = claudeTargetConfig.programs.claude-code-profiles.profileDefaults.default.rules.r;
    expected = "rule body";
  };
  "test the claude-code target sets nothing while it is disabled" = {
    expr = codexHooked.programs.claude-code-profiles;
    expected = {};
  };
  "test the claude-code target asserts on its frontmatter hooks" = {
    expr = failedOf claudeTargetHookProblems;
    expected = ["profile 'default' agent 'a' extra.claude-code.hooks: Stop[0].hooks[0] (type command) sets `once`, which Claude Code honours only in skill frontmatter"];
  };
  "test claude-code takes an LSP startupTimeout from extra.claude-code" = {
    expr = javaLike.lspServers.java.startupTimeout;
    expected = 120000;
  };
  "test a rule with claude-code extra gets frontmatter even without paths" = {
    expr = ruleWithExtra.rules.plain;
    expected = "---\nglobs:\n  - '*.md'\n---\n\nplain body";
  };
  "test claude-code reports an entry's set fields it cannot express" = {
    expr = claudeRendered.dropped.agents;
    expected = {demo = ["category" "reasoningEffort"];};
  };
  "test claude-code reports nothing for fields it reads or left at their default" = {
    expr = (toClaude {agents.plain.prompt.text = "x";}).dropped;
    expected = {};
  };
  "test claude-code reports another target's extra as dropped" = {
    expr = (toClaude {skills.s.extra.codex.policy.products = ["codex"];}).dropped;
    expected = {skills.s = ["extra.codex"];};
  };
  "test claude-code renders no settings hooks of its own from a shared profile" = {
    expr = claudeRendered.hooks;
    expected = {};
  };
  "test claude-code drops another provider's model from agents, skills and commands, and reports it" = {
    expr = (toClaude modelsOfEveryProvider).dropped;
    expected = {
      agents.openai = ["model"];
      agents.qualified = ["model"];
      skills.openai = ["model"];
      commands.openai = ["model"];
    };
  };
  "test claude-code writes no model line for another provider's model" = {
    expr = map (lib.hasInfix "model:") (with toClaude modelsOfEveryProvider; [agents.openai agents.qualified skills.openai commands.openai]);
    expected = [false false false false];
  };
  "test claude-code keeps its own aliases, a context suffix and a full claude id" = {
    expr = map (name: lib.hasInfix "model: '${modelsOfEveryProvider.agents.${name}.model}'" (toClaude modelsOfEveryProvider).agents.${name}) ["alias" "suffixed" "full"];
    expected = [true true true];
  };
}
