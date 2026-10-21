# The claude-code target.
{
  pkgs,
  lib,
  ...
}: let
  inherit (import ../../tests/fixtures.nix {inherit pkgs lib;}) claudeAgentWith codexHooked evalCodingConfig expect expectText failedOf libWithCustom mcpEntry normalize passthroughAgent profile rule skillEntry sourceSpec spec tryMessage typed;

  claudeSettingsHooks = import ../../../claude-code/settings-hooks.nix {
    inherit lib;
    inherit (libWithCustom.custom) mkHookSchema;
  };

  renderClaude = import ./render.nix {
    inherit claudeSettingsHooks pkgs;
    lib = libWithCustom;
    customLib = libWithCustom.custom;
  };

  toClaude = raw: renderClaude (typed raw);

  renderedPassthroughAgent = (toClaude (profile {inherit ((normalize {agents.demo = claudeAgentWith {prompt = spec passthroughAgent;};})) agents;})).agents.demo;

  claudeValidation = import ./validation.nix {inherit claudeSettingsHooks lib;};
  lspEntry = attrs:
    {
      command = "l";
      args = [];
      env = {};
      extensionToLanguage.".l" = "l";
      enabled = true;
      initializationOptions = {};
      extra = {};
    }
    // attrs;

  remoteWithAuth = mcpEntry {
    type = "remote";
    url = "https://mcp.example";
    headersHelper = "print-headers";
    toolTimeout = 30000;
    oauth = {
      clientId = "cid";
      callbackPort = 8080;
      scopes = ["read" "write"];
    };
  };

  claudeExtras = toClaude (profile {
    mcpServers = {
      remote = remoteWithAuth;
      off = mcpEntry {
        command = "off";
        enabled = false;
      };
      sse =
        remoteWithAuth
        // {
          extra.claude-code = {
            type = "sse";
            oauth.authServerMetadataUrl = "https://auth.example/meta";
          };
        };
    };
    lspServers = {
      l = lspEntry {initializationOptions.formatting = true;};
      off = lspEntry {enabled = false;};
    };
    agents.demo = claudeAgentWith {
      color = "cyan";
      extra.claude-code = {
        permissionMode = "plan";
        isolation = "worktree";
        tools = ["Grep"];
        hooks.PreToolUse = [
          {
            matcher = "Bash";
            hooks = [
              {
                type = "command";
                command = "guard";
              }
            ];
          }
        ];
      };
    };
    commands.ship = {
      description = "Ship it";
      argumentHint = null;
      allowedTools = [];
      model = "opus";
      agent = "Explore";
      subtask = true;
      content = spec "ship body";
      extra.claude-code.effort = "high";
    };
    skills.licensed = skillEntry {
      description = "d";
      version = "1.2";
      license = "MIT";
      compatibility = "needs git";
      metadata.owner = "addg";
      prompt = spec "skill body";
      extra.claude-code.arguments = ["issue" "branch"];
    };
  });

  claudeRendered = toClaude {
    description = "";
    instructions = sourceSpec;
    mcpServers = {};
    lspServers = {};
    commands = {};
    skills.versioned = skillEntry {
      description = "d";
      version = "1.2";
      prompt = spec "skill body";
    };
    rules.plain = rule "plain body";
    agents.demo = claudeAgentWith {};
  };

  frontmatterHooks = toClaude (profile {
    agents.guarded = claudeAgentWith {
      extra.claude-code.hooks.Stop = [
        {
          hooks = [
            {
              type = "command";
              command = "check";
              timeout = 5;
            }
          ];
        }
      ];
    };
    skills.formatted = skillEntry {
      description = "d";
      prompt = spec "skill body";
      extra.claude-code.hooks.PostToolUse = [
        {
          matcher = "Edit";
          hooks = [
            {
              type = "command";
              command = "fmt";
              once = true;
            }
          ];
        }
      ];
    };
  });
  misspelledAgentHook = tryMessage (toClaude (profile {agents.bad = claudeAgentWith {extra.claude-code.hooks.PreToolUs = [];};})).agents.bad;
  hookMessages = claudeValidation.frontmatterHookProblems "profile 'p'" (typed {
    agents.a = {
      prompt = spec "x";
      extra.claude-code.hooks.Stop = [
        {
          hooks = [
            {
              type = "command";
              command = "c";
              once = true;
            }
          ];
        }
      ];
    };
    skills.s = {
      prompt = spec "x";
      resourcesRoot = null;
      extra.claude-code.hooks.Stop = [
        {
          hooks = [
            {
              type = "command";
              command = "c";
              once = true;
            }
          ];
        }
      ];
    };
  });

  claudeTargetConfig = evalCodingConfig {
    programs.code-assistant-profiles = {
      targets.claude-code.enable = true;
      profiles.default.rules.r.content.text = "rule body";
    };
  };

  claudeTargetHookProblems = evalCodingConfig {
    programs.code-assistant-profiles = {
      targets.claude-code.enable = true;
      profiles.default.agents.a = {
        prompt.text = "a";
        extra.claude-code.hooks.Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "c";
                once = true;
              }
            ];
          }
        ];
      };
    };
  };

  javaLike = toClaude (profile {lspServers.java = lspEntry {extra.claude-code.startupTimeout = 120000;};});

  ruleWithExtra = toClaude (profile {rules.plain = rule "plain body" // {extra.claude-code.globs = ["*.md"];};});
in
  pkgs.runCommand "code-assistant-profiles-claude-code-test" {} ''
    ${expect "claude-code passes an instructions source through unread" claudeRendered.instructions sourceSpec}
    ${expectText "claude-code drops the effort level it has no name for" claudeRendered.agents.demo {
      contains = ["description: 'A demo agent'"];
      lacks = ["effort"];
    }}
    ${expectText "claude-code drops an ultra effort it has no name for" (toClaude (profile {agents.demo = claudeAgentWith {reasoningEffort = "ultra";};})).agents.demo {
      contains = ["description: 'A demo agent'"];
      lacks = ["effort"];
    }}
    ${expect "claude-code emits an agent's declared tools" (lib.hasInfix "  - 'Read'" claudeRendered.agents.demo) true}
    ${expect "a rule with no paths renders as its bare source" claudeRendered.rules.plain "plain body"}
    ${expectText "claude-code omits the agent category it does not read" claudeRendered.agents.demo {
      contains = ["name: 'demo'"];
      lacks = ["category"];
    }}
    ${expect "claude-code nests a skill's version under metadata" (lib.hasInfix "metadata:\n  version: '1.2'" claudeRendered.skills.versioned) true}
    ${expectText "claude-code emits no top-level skill version" claudeRendered.skills.versioned {
      contains = ["metadata:\n  version: '1.2'"];
      lacks = ["\nversion:"];
    }}
    ${expect "claude-code emits an LSP server's extension map"
      (toClaude (profile {
        lspServers.l = {
          command = "l";
          args = [];
          env = {};
          extensionToLanguage.".l" = "l";
        };
      })).lspServers.l.extensionToLanguage {".l" = "l";}}

    ${expect "claude-code leaves a disabled MCP server out" (lib.attrNames claudeExtras.mcpServers) ["remote" "sse"]}
    ${expect "claude-code maps a remote server's tool timeout, headers helper and oauth, scopes space-joined" claudeExtras.mcpServers.remote {
      type = "http";
      url = "https://mcp.example";
      headersHelper = "print-headers";
      timeout = 30000;
      oauth = {
        clientId = "cid";
        callbackPort = 8080;
        scopes = "read write";
      };
    }}
    ${expect "claude-code merges MCP extra last, overriding the transport and keeping sibling oauth fields" (with claudeExtras.mcpServers.sse; [type oauth.clientId oauth.authServerMetadataUrl]) ["sse" "cid" "https://auth.example/meta"]}
    ${expect "claude-code leaves a disabled LSP server out" (lib.attrNames claudeExtras.lspServers) ["l"]}
    ${expect "claude-code passes an LSP server's initializationOptions" claudeExtras.lspServers.l.initializationOptions {formatting = true;}}
    ${expect "claude-code passes a Claude color name through" (lib.hasInfix "color: 'cyan'" claudeExtras.agents.demo) true}
    ${expect "claude-code merges agent extra fields into the frontmatter" (map (line: lib.hasInfix line claudeExtras.agents.demo) ["permissionMode: 'plan'" "isolation: 'worktree'"]) [true true]}
    ${expect "an agent's extra overrides the field the shared layer rendered" (lib.hasInfix "tools:\n  - 'Grep'\n" claudeExtras.agents.demo) true}
    ${expect "claude-code renders nested agent hooks from extra as YAML, not inline JSON" (lib.hasInfix "hooks:\n  PreToolUse:\n    - hooks:\n        - command: 'guard'\n          type: 'command'\n      matcher: 'Bash'\n" claudeExtras.agents.demo) true}
    ${expect "claude-code forks a subtask command and passes its model, agent and extra" (map (line: lib.hasInfix line claudeExtras.commands.ship) ["context: 'fork'" "model: 'opus'" "agent: 'Explore'" "effort: 'high'"]) [true true true true]}
    ${expect "claude-code emits a skill's license, compatibility and metadata beside its version" (map (line: lib.hasInfix line claudeExtras.skills.licensed) ["license: 'MIT'" "compatibility: 'needs git'" "metadata:\n  owner: 'addg'\n  version: '1.2'"]) [true true true]}
    ${expect "claude-code merges skill extra into the frontmatter" (lib.hasInfix "arguments:\n  - 'issue'\n  - 'branch'" claudeExtras.skills.licensed) true}

    ${expect "a passthrough boolean renders unquoted in the agent frontmatter" (map (line: lib.hasInfix line renderedPassthroughAgent) ["background: true\n" "memory: 'project'\n" "count: 3\n"]) [true true true]}
    ${expect "claude-code renders typed agent frontmatter hooks without unset fields" (lib.hasInfix "hooks:\n  Stop:\n    - hooks:\n        - command: 'check'\n          timeout: 5\n          type: 'command'\n" frontmatterHooks.agents.guarded) true}
    ${expect "claude-code keeps once on a skill frontmatter hook" (lib.hasInfix "hooks:\n  PostToolUse:\n    - hooks:\n        - command: 'fmt'\n          once: true\n          type: 'command'\n      matcher: 'Edit'\n" frontmatterHooks.skills.formatted) true}
    ${expect "a misspelled event in agent frontmatter hooks fails evaluation" misspelledAgentHook "threw"}
    ${expect "once in agent frontmatter hooks fails an assertion, but not in skill frontmatter" hookMessages ["profile 'p' agent 'a' extra.claude-code.hooks: Stop[0].hooks[0] (type command) sets `once`, which Claude Code honours only in skill frontmatter"]}

    ${expect "the claude-code target enables claude-code-profiles" claudeTargetConfig.programs.claude-code-profiles.enable true}
    ${expect "the claude-code target renders each resolved profile into profileDefaults" (lib.attrNames claudeTargetConfig.programs.claude-code-profiles.profileDefaults) ["default"]}
    ${expect "the claude-code target renders a profile's rules" claudeTargetConfig.programs.claude-code-profiles.profileDefaults.default.rules.r "rule body"}
    ${expect "the claude-code target sets nothing while it is disabled" codexHooked.programs.claude-code-profiles {}}
    ${expect "the claude-code target asserts on its frontmatter hooks" (failedOf claudeTargetHookProblems) ["profile 'default' agent 'a' extra.claude-code.hooks: Stop[0].hooks[0] (type command) sets `once`, which Claude Code honours only in skill frontmatter"]}
    ${expect "claude-code takes an LSP startupTimeout from extra.claude-code" javaLike.lspServers.java.startupTimeout 120000}
    ${expect "a rule with claude-code extra gets frontmatter even without paths" ruleWithExtra.rules.plain "---\nglobs:\n  - '*.md'\n---\n\nplain body"}


    ${expect "claude-code reports an entry's set fields it cannot express" claudeRendered.dropped.agents {demo = ["category" "reasoningEffort"];}}
    ${expect "claude-code reports nothing for fields it reads or left at their default" (toClaude {agents.plain.prompt.text = "x";}).dropped {}}
    ${expect "claude-code reports another target's extra as dropped" (toClaude {skills.s.extra.codex.policy.products = ["codex"];}).dropped {skills.s = ["extra.codex"];}}
    ${expect "claude-code renders no settings hooks of its own from a shared profile" claudeRendered.hooks {}}

    echo "code-assistant-profiles: claude-code target checks OK"
    touch "$out"
  ''
