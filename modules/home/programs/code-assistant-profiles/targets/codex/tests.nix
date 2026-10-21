# The codex target.
{
  pkgs,
  lib,
  ...
}: let
  inherit (import ../../tests/fixtures.nix {inherit pkgs lib;}) codexHooked codexHookTargets evalCodingConfig evalProfiles evalTargets expect expectText failedOf fixtureBody fixtureFile invocationConfig invocationProfile libWithCustom manyLines optionalFieldsConfig spec tryMessage typed;

  renderCodex = import ./render.nix {
    inherit pkgs;
    lib = libWithCustom;
    customLib = libWithCustom.custom;
    codexHooks = import ./hooks.nix {
      inherit lib;
      inherit (libWithCustom.custom) mkHookSchema;
    };
    hooks = {};
    skillsDir = "/home/t/.agents/skills";
  };

  toCodex = raw: renderCodex (typed raw);

  invocationRendered = toCodex invocationConfig;
  optionalRendered = toCodex optionalFieldsConfig;

  sameAsDefault = evalProfiles {
    default.mcpServers.kept.command = "kept";
    skillsOnly = {
      extends = "default";
      skills.extra.prompt.text = "extra";
    };
  };

  codexProfiles = evalProfiles {
    default = {
      instructions.text = "base";
      rules.shared.content.text = "shared rule";
      mcpServers = {
        kept.command = "kept";
        retuned.command = "retuned";
        dropped.command = "dropped";
      };
    };
    ops = {
      extends = "default";
      instructions.text = "ops focus";
      rules.oncall.content.text = "page the owner";
      mcpServers.retuned = {
        command = "retuned";
        args = ["--fast"];
      };
      mcpServers.grafana.command = "grafana";
    };
    standalone.mcpServers.kept.command = "kept";
    skillsOnly = {
      extends = "default";
      skills.extra.prompt = spec "extra";
    };
  };

  scopedProfileOverBudget = evalProfiles {
    default = {};
    long.rules.long = {
      paths = ["**/*.ts"];
      content.text = manyLines;
    };
  };

  codexSkillsConfig = {
    skills.inline.prompt = spec "see \${SKILL_DIR}/notes.md";
    skills.bundled = {
      prompt = spec "bundled";
      resourcesRoot = ../../tests/fixtures/clean;
    };
  };
  codexSkills = evalTargets codexSkillsConfig;

  codexFile = path: invocationRendered.skills.${path};

  # A heredoc would end at a prompt line reading EOF.
  bundledWithEof =
    (toCodex {
      skills.bundled = {
        prompt = spec "before\nEOF\nafter";
        resourcesRoot = ../../tests/fixtures/clean;
      };
    }).skills.bundled.source;

  codexBundledManual = toCodex {
    skills.bundled = {
      prompt = spec "bundled";
      resourcesRoot = ../../tests/fixtures/clean;
      invocation.model = false;
    };
  };

  codexAgentsConfig = {
    agents.reviewer = {
      description = "Reviews a diff";
      prompt = spec "review it";
      model = "gpt-6-luna";
      reasoningEffort = "ultra";
    };
    agents.aliased = {
      prompt = spec "aliased";
      model = "sonnet";
    };
    agents.qualified = {
      prompt = spec "qualified";
      model = "ai-proxy/gpt-6-luna";
    };
  };
  codexAgents = evalTargets codexAgentsConfig;
  codexAgentFile = name: (toCodex codexAgentsConfig).agents."${name}.toml".source;

  codexMcp = optionalRendered.mcpServers;

  codexHookConfig = codexHookTargets {
    PreToolUse = [
      {
        matcher = "^Bash$";
        hooks = [
          {
            type = "command";
            command = "guard";
            timeout = 30;
            statusMessage = "Checking Bash";
          }
        ];
      }
    ];
    SessionStart = [
      {
        hooks = [
          {
            type = "mcp_tool";
            server = "memory";
            tool = "load";
            input.path = "\${cwd}";
          }
        ];
      }
    ];
  } {};
  codexEvents = ["PreToolUse" "PermissionRequest" "PostToolUse" "PreCompact" "PostCompact" "SessionStart" "SessionEnd" "UserPromptSubmit" "SubagentStart" "SubagentStop" "Stop" "Interrupt"];
  # Compared as JSON so the check does not hinge on the TOML writer's layout.
  expectToml = label: file: expected: ''
    actual=$(${pkgs.python3.interpreter} -c 'import json, sys, tomllib; print(json.dumps(tomllib.load(open(sys.argv[1], "rb")), sort_keys=True, separators=(",", ":")))' ${file})
    test "$actual" = ${lib.escapeShellArg (builtins.toJSON expected)} || {
      echo "FAIL ${label}: expected "${lib.escapeShellArg (builtins.toJSON expected)}", got $actual" >&2
      exit 1
    }
  '';

  disabledWithHooks = evalCodingConfig {
    programs.code-assistant-profiles = {
      targets.codex = {
        enable = lib.mkForce false;
        hooks.Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "c";
              }
            ];
          }
        ];
      };
      profiles.default = {};
    };
  };

  multiParent = evalProfiles {
    default.instructions.text = "base";
    ops = {
      extends = "default";
      instructions.text = "ops focus";
    };
    both = {
      extends = ["default" "ops"];
      instructions.text = "both focus";
    };
  };
in
  pkgs.runCommand "code-assistant-profiles-codex-test" {} ''
    ${expect "codex writes an inline skill under ~/.agents/skills" (codexSkills.home.file ? ".agents/skills/inline/SKILL.md") true}
    ${expect "codex links a skill with resources under ~/.agents/skills" (codexSkills.home.file ? ".agents/skills/bundled") true}
    ${expect "codex leaves its deprecated CODEX_HOME skills dir empty" (codexSkills.programs.codex ? skills) false}
    ${expect "codex points SKILL_DIR at the skill's ~/.agents/skills dir" (lib.hasInfix "see /home/t/.agents/skills/inline/notes.md" (toCodex codexSkillsConfig).skills."inline/SKILL.md".text) true}
    ${expect "codex inlines an instructions source" (toCodex {instructions.source = fixtureFile;}).instructions fixtureBody}
    ${expect "codex titles a path-scoped rule by name when it has no description"
      (toCodex {
        rules.comments = {
          paths = ["**/*.{ts,nix}"];
          content = spec "rule body";
        };
      }).instructions "## comments\n\nApplies to: **/*.{ts,nix}\n\nrule body"}
    ${expect "codex writes each agent as a custom agent file in CODEX_HOME" (lib.attrNames (lib.filterAttrs (path: _: lib.hasPrefix ".config/codex/agents/" path) codexAgents.home.file)) [".config/codex/agents/aliased.toml" ".config/codex/agents/qualified.toml" ".config/codex/agents/reviewer.toml"]}
    ${expect "codex no longer renders an agent as a skill" (lib.any (lib.hasPrefix ".agents/skills/") (lib.attrNames codexAgents.home.file)) false}
    ${expect "codex writes an implicit-invocation policy for a manual-only skill" (codexFile "manual/agents/openai.yaml").text (builtins.toJSON {policy.allow_implicit_invocation = false;})}
    ${expect "codex writes no policy for a model-invocable skill" (invocationRendered.skills ? "background/agents/openai.yaml") false}
    ${expectText "codex SKILL.md carries only name and description" (codexFile "versioned/SKILL.md").text {
      contains = ["name: 'versioned'" "description: 'versioned'"];
      lacks = ["argument-hint:" "allowed-tools:" "model:" "context:" "version:" "user-invocable:"];
    }}
    ${expectText "codex drops the disable-model-invocation field it ignores" (codexFile "manual/SKILL.md").text {
      contains = ["name: 'manual'" "manual body"];
      lacks = ["disable-model-invocation"];
    }}
    ${expect "codex renders typed hooks into programs.codex.hooks without unset fields" codexHookConfig.programs.codex.hooks {
      PreToolUse = [
        {
          matcher = "^Bash$";
          hooks = [
            {
              type = "command";
              command = "guard";
              timeout = 30;
              statusMessage = "Checking Bash";
            }
          ];
        }
      ];
      SessionStart = [
        {
          hooks = [
            {
              type = "mcp_tool";
              server = "memory";
              tool = "load";
              input.path = "\${cwd}";
            }
          ];
        }
      ];
    }}
    ${expect "codex hooks pass their checks" (failedOf codexHookConfig) []}
    ${expect "codex writes no hooks when none are declared" (codexHooked.programs.codex ? hooks) false}
    ${expect "codex hooks set while the codex target is disabled are named in a warning" disabledWithHooks.warnings [
      "programs.code-assistant-profiles.targets.codex.hooks is set, but programs.code-assistant-profiles.targets.codex.enable is false, so no Codex hook is written"
    ]}
    ${expect "a disabled codex target writes none of its hooks" (disabledWithHooks.programs.codex ? hooks) false}
    ${expect "codex hooks raise no warning while the codex target is enabled" codexHookConfig.warnings []}
    ${expect "codex accepts and renders all twelve documented events" (lib.attrNames
      (codexHookTargets (lib.genAttrs codexEvents (_: [
        {
          hooks = [
            {
              type = "command";
              command = "c";
            }
          ];
        }
      ])) {}).programs.codex.hooks) (lib.sort (a: b: a < b) codexEvents)}
    ${expect "a misspelled codex hook event fails evaluation" (tryMessage (codexHookTargets {PreToolUs = [];} {}).programs.codex) "threw"}
    ${expect "a codex prompt handler fails evaluation, since Codex skips it" (tryMessage (codexHookTargets {Stop = [{hooks = [{type = "prompt";}];}];} {}).programs.codex) "threw"}
    ${expect "a codex command handler on the same event evaluates" (tryMessage
      (codexHookTargets {
        Stop = [
          {
            hooks = [
              {
                type = "command";
                command = "c";
              }
            ];
          }
        ];
      } {}).programs.codex) "no throw"}
    ${expect "codex hooks Codex would ignore or reject fail assertions" (failedOf (codexHookTargets {
        Stop = [
          {
            matcher = "x";
            hooks = [
              {
                type = "command";
                command = "c";
                server = "s";
              }
            ];
          }
        ];
        SessionEnd = [
          {
            hooks = [
              {
                type = "mcp_tool";
                server = "s";
                tool = "t";
                timeout = 10;
              }
              {
                type = "command";
                command = "c";
                async = true;
                additionalContextLimit = 10;
              }
            ];
          }
        ];
        PreToolUse = [
          {
            hooks = [
              {
                type = "mcp_tool";
                server = "s";
                input.a = null;
              }
              {
                type = "command";
                command = "c";
                additionalContextLimit = 0;
              }
            ];
          }
        ];
      } {})) (map (m: "programs.code-assistant-profiles.targets.codex.hooks: ${m}") [
        "Stop[0] sets matcher 'x', but Codex ignores matchers on Stop"
        "Stop[0].hooks[0] (type command) sets `server`, which only applies to mcp_tool handlers"
        "PreToolUse[0].hooks[0] (type mcp_tool) is missing required `tool`"
        "PreToolUse[0].hooks[0] (type mcp_tool) has a null in `input`, which Codex rejects because it must be TOML-representable"
        "SessionEnd[0].hooks[0] (type mcp_tool) is an mcp_tool handler, which Codex does not run on SessionEnd"
        "SessionEnd[0].hooks[0] (type mcp_tool) sets timeout 10, above the 3 second ceiling Codex clamps SessionEnd to"
        "SessionEnd[0].hooks[1] (type command) sets `async`, but Codex always runs SessionEnd hooks synchronously"
        "SessionEnd[0].hooks[1] (type command) sets `additionalContextLimit`, but SessionEnd cannot emit additionalContext"
      ])}

    ${expect "codex maps a local server's cwd, timeouts and disabled state, then merges extra" codexMcp.local {
      command = "srv";
      cwd = "/srv";
      enabled = false;
      startup_timeout_ms = 20000;
      tool_timeout_sec = 1.5;
      required = true;
    }}
    ${expect "codex maps a remote server's headers helper, oauth client and scopes list" codexMcp.remote {
      url = "https://mcp.example";
      http_headers_helper = "print-headers";
      oauth = {
        client_id = "cid";
        callback_port = 8080;
        callback_url = "http://localhost:8080/cb";
      };
      scopes = ["read" "write"];
    }}
    ${expect "codex leaves an enabled server's enabled field unset" (codexMcp.remote ? enabled) false}
    ${expectToml "codex merges an agent's codex extra into its TOML" optionalRendered.agents."painter.toml".source {
      name = "painter";
      description = "painter";
      developer_instructions = "paint";
      sandbox_mode = "read-only";
    }}
    ${expect "codex carries a skill's short-description metadata and nothing else from it" (lib.hasInfix "metadata:\n  short-description: 'Short'\n" optionalRendered.skills."licensed/SKILL.md".text) true}
    ${expectText "codex drops the license it does not read" optionalRendered.skills."licensed/SKILL.md".text {
      contains = ["name: 'licensed'" "licensed body"];
      lacks = ["license:"];
    }}
    ${expect "codex writes skill extra to agents/openai.yaml" optionalRendered.skills."licensed/agents/openai.yaml".text (builtins.toJSON {interface.display_name = "Licensed";})}
    ${expect "codex merges skill extra with the manual-only policy" optionalRendered.skills."manualExtra/agents/openai.yaml".text (builtins.toJSON {
      policy = {
        allow_implicit_invocation = false;
        products = ["codex"];
      };
    })}

    ${expect "codex layers a non-default profile's MCP changes and own instructions over the default" codexProfiles.programs.codex.profiles.ops {
      mcp_servers = {
        grafana.command = "grafana";
        retuned = {
          command = "retuned";
          args = ["--fast"];
        };
      };
      developer_instructions = "ops focus\n\npage the owner";
    }}
    ${expect "codex disables default MCP servers a profile that extends nothing lacks" codexProfiles.programs.codex.profiles.standalone {
      mcp_servers = {
        dropped.enabled = false;
        retuned.enabled = false;
      };
    }}
    ${expect "codex writes no profile file when a profile differs only in what Codex reads globally" (codexProfiles.programs.codex.profiles ? skillsOnly) false}
    ${expect "codex never writes the default profile as a profile file" (codexProfiles.programs.codex.profiles ? default) false}
    ${expect "a profile name codex --profile rejects fails an assertion" (failedOf (evalProfiles {
      default = {};
      "deep.review" = {};
    })) ["programs.code-assistant-profiles.profiles.\"deep.review\": Codex `--profile` accepts only letters, digits, `-` and `_`, so the codex target cannot select it"]}
    ${expect "an over-budget path-scoped rule warns for a non-default profile codex renders" (lib.any (lib.hasInfix "profile 'long' as codex/opencode inline it") scopedProfileOverBudget.warnings) true}

    ${expect "a codex profile that renders to nothing is named in a warning" sameAsDefault.warnings [
      "programs.code-assistant-profiles.profiles.\"skillsOnly\": a Codex profile carries only MCP servers and instructions, and these match \"default\"'s, so the codex target writes no `skillsOnly` profile and `codex --profile skillsOnly` cannot select it"
    ]}

    ${expectToml "codex maps an agent's description, prompt, model and effort onto its custom agent fields" (codexAgentFile "reviewer") {
      name = "reviewer";
      description = "Reviews a diff";
      developer_instructions = "review it";
      model = "gpt-6-luna";
      model_reasoning_effort = "ultra";
    }}
    ${expectToml "codex drops a Claude model alias and falls back to the agent name for a missing description" (codexAgentFile "aliased") {
      name = "aliased";
      description = "aliased";
      developer_instructions = "aliased";
    }}
    ${expectToml "codex drops a provider-qualified model an agent file cannot route" (codexAgentFile "qualified") {
      name = "qualified";
      description = "qualified";
      developer_instructions = "qualified";
    }}

    grep -qx after ${bundledWithEof}/SKILL.md || {
      echo "FAIL codex writes a bundled skill's SKILL.md whole, past a line reading EOF" >&2
      exit 1
    }
    grep -qx 'name: .bundled.' ${bundledWithEof}/SKILL.md || {
      echo "FAIL codex writes a bundled skill's SKILL.md frontmatter" >&2
      exit 1
    }

    test "$(cat ${codexBundledManual.skills.bundled.source}/agents/openai.yaml)" = ${lib.escapeShellArg (builtins.toJSON {policy.allow_implicit_invocation = false;})} || {
      echo "FAIL codex bundles the implicit-invocation policy into a skill with resources" >&2
      exit 1
    }

    ${expect "codex exposes the skill names it writes to ~/.agents/skills" (lib.sort (a: b: a < b) invocationProfile.programs.code-assistant-profiles.targets.codex.writtenSkillNames) ["background" "commit" "manual" "shared" "versioned"]}
    ${expect "codex writes a multi-parent profile's own instructions once, without the default's" multiParent.programs.codex.profiles.both.developer_instructions "ops focus\n\nboth focus"}

    ${expect "codex reports an agent's Claude-only fields and Claude model alias as dropped"
      (toCodex {
        agents.a = {
          prompt = spec "a";
          model = "sonnet";
          tools = ["Read"];
          color = "red";
        };
      }).dropped {agents.a = ["color" "model" "tools"];}}
    ${expect "codex reports the models it cannot route and nothing for an agent it expresses whole" (toCodex codexAgentsConfig).dropped.agents {
      aliased = ["model"];
      qualified = ["model"];
    }}
    ${expect "codex reports every set field of an LSP server, having no LSP client"
      (toCodex {
        lspServers.l = {
          command = "l";
          extensionToLanguage.".l" = "l";
        };
      }).dropped {lspServers.l = ["command" "extensionToLanguage"];}}
    ${expect "codex reports skill metadata beyond short-description as dropped"
      (toCodex {
        skills.s = {
          prompt = spec "s";
          metadata = {
            "short-description" = "Short";
            owner = "addg";
          };
        };
      }).dropped {skills.s = ["metadata"];}}

    echo "code-assistant-profiles: codex target checks OK"
    touch "$out"
  ''
