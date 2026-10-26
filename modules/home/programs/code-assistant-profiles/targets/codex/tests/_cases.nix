# The codex target's renders and evaluated fixtures, shared by its unit and files tests.
{
  harness,
  lib,
  pkgs,
}: let
  inherit (import ../../../tests/_fixtures.nix {inherit harness lib pkgs;}) codexHookTargets codexHooked evalCodingConfig evalProfiles evalTargets failedOf fixtureBody fixtureFile forced invocationConfig invocationProfile libWithCustom manyLines needleProblems noNeedleProblems optionalFieldsConfig spec typed;

  renderCodex = import ../render.nix {
    inherit pkgs;
    lib = libWithCustom;
    customLib = libWithCustom.custom;
    codexHooks = import ../hooks.nix {
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
      resourcesRoot = ../../../tests/fixtures/clean;
    };
  };
  codexSkills = evalTargets codexSkillsConfig;

  # Each skill is a built directory, so its files are read when a files: test runs.
  skillFile = rendered: dir: file: "${rendered.skills.${dir}.source}/${file}";
  codexFile = path: let
    parts = lib.splitString "/" path;
  in
    skillFile invocationRendered (lib.head parts) (lib.concatStringsSep "/" (lib.tail parts));
  homeSkillFile = config: dir: "${config.home.file.".agents/skills/${dir}".source}/SKILL.md";

  # A heredoc would end at a prompt line reading EOF.
  bundledWithEof =
    (toCodex {
      skills.bundled = {
        prompt = spec "before\nEOF\nafter";
        resourcesRoot = ../../../tests/fixtures/clean;
      };
    }).skills.bundled.source;

  codexBundledManual = toCodex {
    skills.bundled = {
      prompt = spec "bundled";
      resourcesRoot = ../../../tests/fixtures/clean;
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
  disabledWithoutHooks = evalCodingConfig {
    programs.code-assistant-profiles.targets.codex.enable = lib.mkForce false;
  };
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

  ownEntries = evalProfiles {
    default.skills.shared.prompt = spec "shared";
    grafana = {
      extends = "default";
      agents.dashboard-builder.prompt = spec "build";
      skills.dashboard-review.prompt = spec "review";
      commands.panel.content = spec "panel";
    };
  };

  clashingEntries = evalProfiles {
    default = {};
    ops = {
      skills.lint.prompt = spec "lint the ops way";
      agents.same.prompt = spec "same";
    };
    other = {
      skills.lint.prompt = spec "lint the other way";
      agents.same.prompt = spec "same";
    };
  };

  # A profile that includes an addon replacing an inherited skill, command and agent.
  ownVersions = evalProfiles {
    default = {
      skills.investigate.prompt = spec "investigate the personal way";
      commands.review.content = spec "review the personal way";
      agents.reviewer.prompt = spec "review personally";
    };
    alt = {
      extends = "default";
      include = [
        {
          skills.investigate.prompt = spec "investigate the alt way";
          commands.review.content = spec "review the alt way";
          agents.reviewer.prompt = spec "review for alt";
        }
      ];
    };
  };
  ownVersionsProfile = ownVersions.programs.codex.profiles.alt;
  variantSkill = dir: "/home/t/.agents/skills/${dir}/SKILL.md";

  takenVariantName = evalProfiles {
    default.skills = {
      lint.prompt = spec "lint";
      "lint--ops".prompt = spec "taken";
    };
    ops = {
      extends = "default";
      skills.lint.prompt = spec "lint the ops way";
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
in {
  inherit bundledWithEof clashingEntries homeSkillFile ownVersions ownVersionsProfile skillFile takenVariantName variantSkill codexAgentFile codexAgents codexAgentsConfig codexBundledManual codexEvents codexFile codexHookConfig codexHookTargets codexHooked codexMcp codexProfiles codexSkills codexSkillsConfig disabledWithHooks disabledWithoutHooks evalCodingConfig evalProfiles evalTargets failedOf fixtureBody fixtureFile forced invocationConfig invocationProfile invocationRendered libWithCustom manyLines multiParent needleProblems noNeedleProblems optionalFieldsConfig optionalRendered ownEntries renderCodex sameAsDefault scopedProfileOverBudget spec toCodex typed;
}
