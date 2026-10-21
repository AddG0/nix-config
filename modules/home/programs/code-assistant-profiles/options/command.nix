# The schema of one command entry.
{lib}: let
  inherit (import ./fields.nix {inherit lib;}) textSourceType extraOption;
in
  lib.types.submodule ({name, ...}: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "Command name.";
      };

      description = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Short description of what the command does.";
      };

      argumentHint = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Optional argument hint shown by tools that support command arguments.";
      };

      allowedTools = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Tool names the command is allowed to invoke.";
      };

      model = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Model to run the command with. opencode takes only a `provider/model` value and drops a bare alias.";
      };

      agent = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Agent that runs the command.";
      };

      subtask = lib.mkOption {
        type = lib.types.nullOr lib.types.bool;
        default = null;
        description = "Run the command as a subagent, outside the main context. claude-code gets `context: fork` when true; opencode gets `subtask`.";
      };

      content = lib.mkOption {
        type = textSourceType;
        default = {};
        description = "Command content as inline text or a source file.";
      };

      extra = extraOption ["claude-code" "codex" "opencode"] {
        codex = "Codex renders the command as a skill, so these reach that skill's agents/openai.yaml.";
      };
    };
  })
