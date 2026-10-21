# The schema of one MCP server entry.
{lib}: let
  inherit (import ./fields.nix {inherit lib;}) extraOption;

  # Claude Code ignores a tool timeout below this.
  minToolTimeoutMs = 1000;
in
  lib.types.submodule ({name, ...}: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        description = "MCP server name.";
      };

      description = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Short description of the MCP server.";
      };

      type = lib.mkOption {
        type = lib.types.enum ["local" "remote"];
        default = "local";
        description = "Whether the MCP server is launched locally or accessed remotely.";
      };

      command = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Executable used to launch a local MCP server.";
      };

      args = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        description = "Arguments for a local MCP server command.";
      };

      env = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Environment variables for a local MCP server.";
      };

      url = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "URL for a remote MCP server.";
      };

      headers = lib.mkOption {
        type = lib.types.attrsOf lib.types.str;
        default = {};
        description = "Headers for a remote MCP server.";
      };

      enabled = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether the server starts. codex and opencode keep a disabled server's config; claude-code has no such field, so it omits the server.";
      };

      startupTimeout = lib.mkOption {
        type = lib.types.nullOr lib.types.ints.positive;
        default = null;
        description = "Milliseconds to wait for the server to start and list its tools. codex `startup_timeout_ms`, opencode `timeout`; claude-code has no per-server equivalent.";
      };

      toolTimeout = lib.mkOption {
        type = lib.types.nullOr (lib.types.addCheck lib.types.int (ms: ms >= minToolTimeoutMs) // {description = "integer of at least ${toString minToolTimeoutMs}";});
        default = null;
        description = "Milliseconds a single tool call may run. claude-code `timeout` (ignored below ${toString minToolTimeoutMs}), codex `tool_timeout_sec`; opencode has no per-server equivalent.";
      };

      cwd = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Working directory of a local MCP server, for codex and opencode.";
      };

      headersHelper = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Shell command printing a JSON object of headers for a remote server. claude-code `headersHelper`, codex `http_headers_helper`.";
      };

      oauth = lib.mkOption {
        type = lib.types.submodule {
          options = {
            clientId = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "Pre-registered OAuth client ID.";
            };

            callbackPort = lib.mkOption {
              type = lib.types.nullOr lib.types.port;
              default = null;
              description = "Fixed local port for the OAuth redirect.";
            };

            scopes = lib.mkOption {
              type = lib.types.listOf lib.types.str;
              default = [];
              description = "OAuth scopes to request.";
            };
          };
        };
        default = {};
        description = "OAuth client settings for a remote server. A client secret would land in the world-readable store, so it goes through `extra` if at all.";
      };

      extra = extraOption ["claude-code" "codex" "opencode"] {};
    };
  })
