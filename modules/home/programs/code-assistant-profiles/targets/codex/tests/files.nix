# The codex target's rendered agent TOML and skill directories, and bad configs only Codex's own validators reject.
{
  harness,
  lib,
  pkgs,
  self,
  ...
}: let
  inherit (import ./_cases.nix {inherit harness lib pkgs;}) checkAgent bundledWithEof codexAgentFile codexBundledManual codexFile codexSkillsConfig homeSkillFile optionalRendered ownVersions skillFile spec toCodex;
  inherit (import ../../../tests/_validators.nix {inherit lib pkgs self;}) validatorRejection;
  inherit (harness) paths;
  brokenAgentBuild = pkgs.testers.testBuildFailure (checkAgent "broken" (pkgs.writeText "broken.toml" "name = ["));

  rejectedByValidator = {
    codex-hook = {
      module = {programs.codex.hooks.PreToolUse = [{hooks = [{type = "command";}];}];};
      expected = ["fixture-codex-hook: codex: .config/codex/hooks.json: `codex mcp list`" "missing field `command`"];
    };
    codex-agent = {
      module = {home.file.".config/codex/agents/broken.toml".text = "name = [";};
      expected = ["fixture-codex-agent: codex: .config/codex: `codex doctor --json`" "agents/broken.toml"];
    };
    codex-hooks-shape = {
      module = {programs.codex.hooks = pkgs.writeText "hooks.json" ''{"hooks": [], "extra": 1}'';};
      expected = ["fixture-codex-hooks-shape: codex: .config/codex/hooks.json: `jq`" "only `description` and an object `hooks`"];
    };
    codex-profile = {
      module = {programs.codex.profiles.alt.mcp_servers = lib.mkForce "none";};
      expected = ["fixture-codex-profile: codex: .config/codex/alt.config.toml: `codex --profile alt mcp list`" "invalid type"];
    };
  };
in
  harness.check "code-assistant-profiles-codex-files" ''
    ${paths.toml "codex merges an agent's codex extra into its TOML" optionalRendered.agents."painter.toml".source {
      name = "painter";
      description = "painter";
      developer_instructions = "paint";
      sandbox_mode = "read-only";
    }}
    ${paths.toml "codex maps an agent's description, prompt, model and effort onto its custom agent fields" (codexAgentFile "reviewer") {
      name = "reviewer";
      description = "Reviews a diff";
      developer_instructions = "review it";
      model = "gpt-6-luna";
      model_reasoning_effort = "ultra";
    }}
    ${paths.toml "codex drops a Claude model alias and falls back to the agent name for a missing description" (codexAgentFile "aliased") {
      name = "aliased";
      description = "aliased";
      developer_instructions = "aliased";
    }}
    ${paths.toml "codex drops a provider-qualified model an agent file cannot route" (codexAgentFile "qualified") {
      name = "qualified";
      description = "qualified";
      developer_instructions = "qualified";
    }}
    ${paths.toml "codex writes no model for Claude's default alias"
      (toCodex {
        agents.claudeDefault = {
          prompt = spec "a";
          model = "default";
        };
      }).agents."claudeDefault.toml".source {
        name = "claudeDefault";
        description = "claudeDefault";
        developer_instructions = "a";
      }}
    ${paths.toml "codex writes a profile's own agent under the shared role name" ownVersions.home.file.".config/codex/agent-variants/reviewer--alt.toml".source {
      name = "reviewer";
      description = "reviewer";
      developer_instructions = "review for alt";
    }}

    ${paths.contains "codex writes a bundled skill's SKILL.md whole, past a line reading EOF" "${bundledWithEof}/SKILL.md" ["\nafter"]}
    ${paths.contains "codex writes a bundled skill's SKILL.md frontmatter" "${bundledWithEof}/SKILL.md" ["name: 'bundled'"]}
    ${paths.content "codex bundles the implicit-invocation policy into a skill with resources" "${codexBundledManual.skills.bundled.source}/agents/openai.yaml" (builtins.toJSON {policy.allow_implicit_invocation = false;})}

    ${paths.contains "codex points SKILL_DIR at the skill's ~/.agents/skills dir" (skillFile (toCodex codexSkillsConfig) "inline" "SKILL.md") ["see /home/t/.agents/skills/inline/notes.md"]}
    ${paths.content "codex writes an implicit-invocation policy for a manual-only skill" (codexFile "manual/agents/openai.yaml") (builtins.toJSON {policy.allow_implicit_invocation = false;})}
    ${paths.missing "codex writes no policy for a model-invocable skill" (codexFile "background/agents/openai.yaml")}
    ${paths.contains "codex SKILL.md carries only name and description" (codexFile "versioned/SKILL.md") ["name: 'versioned'" "description: 'versioned'"]}
    ${paths.lacks "codex SKILL.md carries only name and description" (codexFile "versioned/SKILL.md") ["argument-hint:" "allowed-tools:" "model:" "context:" "version:" "user-invocable:"]}
    ${paths.contains "codex drops the disable-model-invocation field it ignores" (codexFile "manual/SKILL.md") ["name: 'manual'" "manual body"]}
    ${paths.lacks "codex drops the disable-model-invocation field it ignores" (codexFile "manual/SKILL.md") ["disable-model-invocation"]}
    ${paths.contains "codex carries a skill's short-description metadata and nothing else from it" (skillFile optionalRendered "licensed" "SKILL.md") ["metadata:\n  short-description: 'Short'\n"]}
    ${paths.contains "codex drops the license it does not read" (skillFile optionalRendered "licensed" "SKILL.md") ["name: 'licensed'" "licensed body"]}
    ${paths.lacks "codex drops the license it does not read" (skillFile optionalRendered "licensed" "SKILL.md") ["license:"]}
    ${paths.content "codex writes skill extra to agents/openai.yaml" (skillFile optionalRendered "licensed" "agents/openai.yaml") (builtins.toJSON {interface.display_name = "Licensed";})}
    ${paths.content "codex merges skill extra with the manual-only policy" (skillFile optionalRendered "manualExtra" "agents/openai.yaml") (builtins.toJSON {
      policy = {
        allow_implicit_invocation = false;
        products = ["codex"];
      };
    })}
    ${paths.contains "codex keeps a profile's own skill's name in its SKILL.md" (homeSkillFile ownVersions "investigate--alt") ["name: 'investigate'" "investigate the alt way"]}
    ${paths.lacks "codex keeps a profile's own skill's name in its SKILL.md" (homeSkillFile ownVersions "investigate--alt") ["personal way"]}
    ${paths.contains "codex keeps a profile's own command's name in its SKILL.md" (homeSkillFile ownVersions "review--alt") ["name: 'review'" "review the alt way"]}
    ${paths.lacks "codex keeps a profile's own command's name in its SKILL.md" (homeSkillFile ownVersions "review--alt") ["personal way"]}
    ${paths.contains "an agent role Codex cannot read fails its TOML's build, naming the role" "${brokenAgentBuild}/testBuildFailure.log" ["codex agent broken: `codex doctor --json` rejected agents/broken.toml" "broken.toml"]}
    ${lib.concatStrings (lib.mapAttrsToList validatorRejection rejectedByValidator)}
  ''
