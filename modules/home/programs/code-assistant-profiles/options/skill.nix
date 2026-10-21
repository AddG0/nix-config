# The schema of one skill entry.
{lib}: let
  inherit (import ./fields.nix {inherit lib;}) textSourceType extraOption reasoningEffortOption;
in
  lib.types.submodule ({name, ...}: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Exported skill name.";
      };

      description = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Short description of what the skill does.";
      };

      whenToUse = lib.mkOption {
        type = lib.types.nullOr lib.types.lines;
        default = null;
        description = "Additional guidance describing when the skill should be selected automatically.";
      };

      argumentHint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional argument hint shown by tools that support skill arguments.";
      };

      invocation = lib.mkOption {
        type = lib.types.submodule {
          options = {
            user = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether the skill can be invoked directly by the user.";
            };

            model = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = "Whether assistants may invoke the skill automatically.";
            };
          };
        };
        default = {};
        description = "Invocation behavior shared across assistants.";
      };

      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["src/api/**/*.ts" "**/*.test.ts"];
        description = "Optional glob patterns that scope when the skill should auto-activate.";
      };

      context = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional execution context hint for tools that support it.";
      };

      reasoningEffort = reasoningEffortOption;

      agent = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional subagent identifier for tools that support delegated skill execution.";
      };

      version = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional version for tools that support skill metadata.";
      };

      license = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "License of the skill, for claude-code and opencode.";
      };

      compatibility = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Environment requirements, for claude-code and opencode. opencode falls back to `opencode`.";
      };

      metadata = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Free-form skill metadata for claude-code and opencode. Codex reads only `short-description`.";
      };

      prompt = lib.mkOption {
        type = textSourceType;
        default = {};
        description = "Skill prompt body as inline text or a source file.";
      };

      resourcesRoot = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Optional directory containing supplementary files referenced by the skill.";
      };

      allowedTools = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Tool names the skill is allowed to invoke.";
      };

      model = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Preferred model for tools that support per-skill model selection.";
      };

      extra = extraOption ["claude-code" "codex" "opencode"] {};
    };
  })
