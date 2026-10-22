# The schema of one agent entry.
{lib}: let
  inherit (import ./fields.nix {inherit lib;}) textSourceType extraOption reasoningEffortOption agentColors;
in
  lib.types.submodule ({name, ...}: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Agent name.";
      };

      description = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Short description of what the agent does.";
      };

      prompt = lib.mkOption {
        type = textSourceType;
        default = {};
        description = "Agent prompt body as inline text or a source file.";
      };

      tools = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Claude Code tool names the agent may use; empty inherits every tool. opencode gets a `permission` map denying `*` and allowing each mapped key.";
      };

      disallowedTools = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Claude Code tool names the agent must never use. claude-code emits a denylist field; opencode maps each to its permission key (`Write` and `Edit` to `edit`, `Agent` to `task`, `mcp__server__tool` to `server_tool`) set to `deny`.";
      };

      skills = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Skill names the agent expects or orchestrates.";
      };

      category = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional agent category for tools that support it.";
      };

      model = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Preferred model for tools that support per-agent model selection. Each target keeps only a model it routes (models.nix: Claude aliases and claude-* ids for claude-code, bare OpenAI ids for codex, `provider/model` for opencode) and reports the rest as dropped.";
      };

      color = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum agentColors);
        default = null;
        description = "Display color. claude-code takes the name; opencode gets a matching hex value.";
      };

      reasoningEffort = reasoningEffortOption;

      maxTurns = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Maximum number of agentic iterations before the agent must stop and return a final response.";
      };

      extra = extraOption ["claude-code" "codex" "opencode"] {};
    };
  })
