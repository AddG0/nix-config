# The codex target: what it renders from the shared profile model.
{
  harness,
  lib,
  pkgs,
  ...
}: let
  inherit (import ./_cases.nix {inherit harness lib pkgs;}) ownVersions ownVersionsProfile takenVariantName variantSkill clashingEntries codexAgents codexAgentsConfig codexEvents codexHookConfig codexHookTargets codexHooked codexMcp codexProfiles codexSkills disabledWithHooks disabledWithoutHooks evalProfiles failedOf fixtureBody fixtureFile forced invocationProfile multiParent ownEntries sameAsDefault scopedProfileOverBudget spec toCodex;
in {
  "test codex writes an inline skill under ~/.agents/skills" = {
    expr = codexSkills.home.file ? ".agents/skills/inline";
    expected = true;
  };
  "test codex links an inline skill as a directory, since Codex skips a symlinked SKILL.md" = {
    expr = lib.any (lib.hasPrefix ".agents/skills/inline/") (lib.attrNames codexSkills.home.file);
    expected = false;
  };
  "test codex links a skill with resources under ~/.agents/skills" = {
    expr = codexSkills.home.file ? ".agents/skills/bundled";
    expected = true;
  };
  "test codex leaves its deprecated CODEX_HOME skills dir empty" = {
    expr = codexSkills.programs.codex ? skills;
    expected = false;
  };
  "test codex inlines an instructions source" = {
    expr = (toCodex {instructions.source = fixtureFile;}).instructions;
    expected = fixtureBody;
  };
  "test codex titles a path-scoped rule by name when it has no description" = {
    expr =
      (toCodex {
        rules.comments = {
          paths = ["**/*.{ts,nix}"];
          content = spec "rule body";
        };
      }).instructions;
    expected = "## comments\n\nApplies to: **/*.{ts,nix}\n\nrule body";
  };
  "test codex writes each agent as a custom agent file in CODEX_HOME" = {
    expr = lib.attrNames (lib.filterAttrs (path: _: lib.hasPrefix ".config/codex/agents/" path) codexAgents.home.file);
    expected = [".config/codex/agents/aliased.toml" ".config/codex/agents/qualified.toml" ".config/codex/agents/reviewer.toml"];
  };
  "test codex no longer renders an agent as a skill" = {
    expr = lib.any (lib.hasPrefix ".agents/skills/") (lib.attrNames codexAgents.home.file);
    expected = false;
  };
  "test codex renders typed hooks into programs.codex.hooks without unset fields" = {
    expr = codexHookConfig.programs.codex.hooks;
    expected = {
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
    };
  };
  "test codex hooks pass their checks" = {
    expr = failedOf codexHookConfig;
    expected = [];
  };
  "test codex writes no hooks when none are declared" = {
    expr = codexHooked.programs.codex ? hooks;
    expected = false;
  };
  "test codex hooks set while the codex target is disabled are named in a warning" = {
    expr = disabledWithHooks.warnings;
    expected = [
      "programs.code-assistant-profiles.targets.codex.hooks is set, but programs.code-assistant-profiles.targets.codex.enable is false, so no Codex hook is written"
    ];
  };
  "test a disabled codex target with no hooks raises no warning" = {
    expr = disabledWithoutHooks.warnings;
    expected = [];
  };
  "test a disabled codex target writes none of its hooks" = {
    expr = disabledWithHooks.programs.codex ? hooks;
    expected = false;
  };
  "test codex hooks raise no warning while the codex target is enabled" = {
    expr = codexHookConfig.warnings;
    expected = [];
  };
  "test codex accepts and renders all twelve documented events" = {
    expr =
      lib.attrNames
      (codexHookTargets (lib.genAttrs codexEvents (_: [
        {
          hooks = [
            {
              type = "command";
              command = "c";
            }
          ];
        }
      ])) {}).programs.codex.hooks;
    expected = lib.sort (a: b: a < b) codexEvents;
  };
  "test a misspelled codex hook event fails evaluation" = {
    expr = forced (codexHookTargets {PreToolUs = [];} {}).programs.codex;
    expectedError.type = "ThrownError";
    expectedError.msg = "hooks\\.PreToolUs' does not exist";
  };
  "test a codex prompt handler fails evaluation, since Codex skips it" = {
    expr = forced (codexHookTargets {Stop = [{hooks = [{type = "prompt";}];}];} {}).programs.codex;
    expectedError.type = "ThrownError";
    expectedError.msg = "is not of type `one of \"command\", \"mcp_tool\"";
  };
  "test a codex command handler on the same event evaluates" = {
    expr =
      builtins.deepSeq
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
      } {}).programs.codex
      true;
    expected = true;
  };
  "test codex hooks Codex would ignore or reject fail assertions" = {
    expr = failedOf (codexHookTargets {
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
    } {});
    expected = map (m: "programs.code-assistant-profiles.targets.codex.hooks: ${m}") [
      "Stop[0] sets matcher 'x', but Codex ignores matchers on Stop"
      "Stop[0].hooks[0] (type command) sets `server`, which only applies to mcp_tool handlers"
      "PreToolUse[0].hooks[0] (type mcp_tool) is missing required `tool`"
      "PreToolUse[0].hooks[0] (type mcp_tool) has a null in `input`, which Codex rejects because it must be TOML-representable"
      "SessionEnd[0].hooks[0] (type mcp_tool) is an mcp_tool handler, which Codex does not run on SessionEnd"
      "SessionEnd[0].hooks[0] (type mcp_tool) sets timeout 10, above the 3 second ceiling Codex clamps SessionEnd to"
      "SessionEnd[0].hooks[1] (type command) sets `async`, but Codex always runs SessionEnd hooks synchronously"
      "SessionEnd[0].hooks[1] (type command) sets `additionalContextLimit`, but SessionEnd cannot emit additionalContext"
    ];
  };
  "test codex maps a local server's cwd, timeouts and disabled state, then merges extra" = {
    expr = codexMcp.local;
    expected = {
      command = "srv";
      cwd = "/srv";
      enabled = false;
      startup_timeout_ms = 20000;
      tool_timeout_sec = 1.5;
      required = true;
    };
  };
  "test codex maps a remote server's headers helper, oauth client and scopes list" = {
    expr = codexMcp.remote;
    expected = {
      url = "https://mcp.example";
      http_headers_helper = "print-headers";
      oauth = {
        client_id = "cid";
        callback_port = 8080;
        callback_url = "http://localhost:8080/cb";
      };
      scopes = ["read" "write"];
    };
  };
  "test codex leaves an enabled server's enabled field unset" = {
    expr = codexMcp.remote ? enabled;
    expected = false;
  };
  "test codex layers a non-default profile's MCP changes and own instructions over the default" = {
    expr = codexProfiles.programs.codex.profiles.ops;
    expected = {
      mcp_servers = {
        grafana.command = "grafana";
        retuned = {
          command = "retuned";
          args = ["--fast"];
        };
      };
      developer_instructions = "ops focus\n\npage the owner";
    };
  };
  "test codex disables default MCP servers a profile that extends nothing lacks" = {
    expr = codexProfiles.programs.codex.profiles.standalone;
    expected = {
      mcp_servers = {
        dropped.enabled = false;
        retuned.enabled = false;
      };
    };
  };
  "test codex writes no profile file when a profile differs only in what Codex reads globally" = {
    expr = codexProfiles.programs.codex.profiles ? skillsOnly;
    expected = false;
  };
  "test codex never writes the default profile as a profile file" = {
    expr = codexProfiles.programs.codex.profiles ? default;
    expected = false;
  };
  "test a profile name codex --profile rejects fails an assertion" = {
    expr = failedOf (evalProfiles {
      default = {};
      "deep.review" = {};
    });
    expected = ["programs.code-assistant-profiles.profiles.\"deep.review\": Codex `--profile` accepts only letters, digits, `-` and `_`, so the codex target cannot select it"];
  };
  "test an over-budget path-scoped rule warns for a non-default profile codex renders" = {
    expr = lib.any (lib.hasInfix "profile 'long' as codex/opencode inline it") scopedProfileOverBudget.warnings;
    expected = true;
  };
  "test a codex profile that renders to nothing is named in a warning" = {
    expr = sameAsDefault.warnings;
    expected = [
      "programs.code-assistant-profiles.profiles.\"skillsOnly\": a Codex profile carries only MCP servers, instructions and its own copies of the default's skills and agents, and these match \"default\"'s, so the codex target writes no `skillsOnly` profile and `codex --profile skillsOnly` cannot select it"
    ];
  };
  "test codex exposes the skill names it writes to ~/.agents/skills" = {
    expr = lib.sort (a: b: a < b) invocationProfile.programs.code-assistant-profiles.targets.codex.writtenSkillNames;
    expected = ["background" "commit" "manual" "shared" "versioned"];
  };
  "test codex writes a non-default profile's own agents, skills and commands to its global dirs" = {
    expr = map (path: ownEntries.home.file ? ${path}) [".config/codex/agents/dashboard-builder.toml" ".agents/skills/dashboard-review" ".agents/skills/panel" ".agents/skills/shared"];
    expected = [true true true true];
  };
  "test codex lists a non-default profile's skill and command names as written" = {
    expr = lib.sort (a: b: a < b) ownEntries.programs.code-assistant-profiles.targets.codex.writtenSkillNames;
    expected = ["dashboard-review" "panel" "shared"];
  };
  "test codex raises no assertion for an entry two profiles share by inheritance" = {
    expr = failedOf ownEntries;
    expected = [];
  };
  "test two profiles defining one Codex entry name differently fail an assertion naming both" = {
    expr = failedOf clashingEntries;
    expected = [
      "programs.code-assistant-profiles: Codex reads skills, commands and agents from global directories, so skill 'lint' differs between profiles \"ops\", \"other\", and the default profile \"default\" has no copy for one of them to replace; define it in \"default\" or rename one"
    ];
  };
  "test codex writes a profile's own skill and command beside the inherited ones, keeping their names" = {
    expr = map (path: ownVersions.home.file ? ${path}) [".agents/skills/investigate" ".agents/skills/investigate--alt" ".agents/skills/review" ".agents/skills/review--alt"];
    expected = [true true true true];
  };
  "test codex disables every profile's own skill and command in the default config" = {
    expr = ownVersions.programs.codex.settings.skills.config;
    expected = [
      {
        path = variantSkill "investigate--alt";
        enabled = false;
      }
      {
        path = variantSkill "review--alt";
        enabled = false;
      }
    ];
  };
  "test codex swaps the inherited skill and command for the profile's own in its profile file" = {
    expr = ownVersionsProfile.skills.config;
    expected = [
      {
        path = variantSkill "investigate";
        enabled = false;
      }
      {
        path = variantSkill "investigate--alt";
        enabled = true;
      }
      {
        path = variantSkill "review";
        enabled = false;
      }
      {
        path = variantSkill "review--alt";
        enabled = true;
      }
    ];
  };
  "test codex moves a replaced agent out of the scanned agents dir and declares the default's copy" = {
    expr = [(ownVersions.home.file ? ".config/codex/agents/reviewer.toml") (ownVersions.home.file ? ".config/codex/agent-variants/reviewer.toml") (ownVersions.home.file ? ".config/codex/agent-variants/reviewer--alt.toml") ownVersions.programs.codex.settings.agents];
    expected = [false true true {reviewer.config_file = "agent-variants/reviewer.toml";}];
  };
  "test codex points a profile's agent role at its own copy in its profile file" = {
    expr = ownVersionsProfile.agents;
    expected = {reviewer.config_file = "agent-variants/reviewer--alt.toml";};
  };
  "test codex raises no assertion when a profile replaces an entry it inherits" = {
    expr = failedOf ownVersions;
    expected = [];
  };
  "test a profile's own copy whose directory name another skill holds fails an assertion" = {
    expr = failedOf takenVariantName;
    expected = [
      "programs.code-assistant-profiles: Codex writes profile \"ops\"'s own skill 'lint' as 'lint--ops', which another skill is already named; rename one"
    ];
  };
  "test codex writes a multi-parent profile's own instructions once, without the default's" = {
    expr = multiParent.programs.codex.profiles.both.developer_instructions;
    expected = "ops focus\n\nboth focus";
  };
  "test codex reports an agent's Claude-only fields and Claude model alias as dropped" = {
    expr =
      (toCodex {
        agents.a = {
          prompt = spec "a";
          model = "sonnet";
          tools = ["Read"];
          color = "red";
        };
      }).dropped;
    expected = {agents.a = ["color" "model" "tools"];};
  };
  "test codex reports the models it cannot route and nothing for an agent it expresses whole" = {
    expr = (toCodex codexAgentsConfig).dropped.agents;
    expected = {
      aliased = ["model"];
      qualified = ["model"];
    };
  };
  "test codex drops Claude's default alias and a model no provider claims, and reports both" = {
    expr =
      (toCodex {
        agents =
          lib.mapAttrs (_: model: {
            prompt = spec "a";
            inherit model;
          }) {
            claudeDefault = "default";
            suffixed = "sonnet[1m]";
            unclaimed = "llama3";
            openai = "o4-mini";
          };
      }).dropped.agents;
    expected = {
      claudeDefault = ["model"];
      suffixed = ["model"];
      unclaimed = ["model"];
    };
  };
  "test codex reports every set field of an LSP server, having no LSP client" = {
    expr =
      (toCodex {
        lspServers.l = {
          command = "l";
          extensionToLanguage.".l" = "l";
        };
      }).dropped;
    expected = {lspServers.l = ["command" "extensionToLanguage"];};
  };
  "test codex reports skill metadata beyond short-description as dropped" = {
    expr =
      (toCodex {
        skills.s = {
          prompt = spec "s";
          metadata = {
            "short-description" = "Short";
            owner = "addg";
          };
        };
      }).dropped;
    expected = {skills.s = ["metadata"];};
  };
}
