# The schema of one LSP server entry.
{lib}: let
  inherit (import ./fields.nix {inherit lib;}) extraOption;
in
  lib.types.submodule ({name, ...}: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "LSP server name.";
      };

      description = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Short description of the LSP server.";
      };

      command = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Executable used to launch the LSP server. Required unless `enabled` is false.";
      };

      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Arguments for the LSP server command.";
      };

      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Environment variables for the LSP server.";
      };

      extensionToLanguage = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Mapping from file extension to language identifier. Required unless `enabled` is false: Claude Code refuses to load an LSP server without one.";
      };

      enabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the server runs. opencode gets `disabled`, which also switches off its built-in server of the same name; claude-code omits the server.";
      };

      initializationOptions = lib.mkOption {
        type = lib.types.attrsOf lib.types.anything;
        default = {};
        description = "Options sent in the LSP initialize request. claude-code `initializationOptions`, opencode `initialization`.";
      };

      extra = extraOption ["claude-code" "opencode"] {
        claude-code = "Claude-only fields such as `startupTimeout` (milliseconds) go here.";
      };
    };
  })
