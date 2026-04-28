{lib}: let
  textSourceOptions = {
    text = lib.mkOption {
      type = lib.types.nullOr lib.types.lines;
      default = null;
      description = "Inline content.";
    };

    source = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Path to a file containing the content.";
    };
  };

  textSourceType = lib.types.submodule {
    options = textSourceOptions;
  };

  commandType = lib.types.submodule ({name, ...}: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        readOnly = true;
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

      content = lib.mkOption {
        type = textSourceType;
        default = {};
        description = "Command content as inline text or a source file.";
      };
    };
  });

  ruleType = lib.types.submodule ({name, ...}: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        readOnly = true;
        description = "Rule name.";
      };

      description = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Short description of what the rule covers.";
      };

      paths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = ["src/api/**/*.ts" "**/*.test.ts"];
        description = "Optional glob patterns that scope when the rule should apply.";
      };

      content = lib.mkOption {
        type = textSourceType;
        default = {};
        description = "Rule content as inline text or a source file.";
      };
    };
  });

  skillType = lib.types.submodule ({name, ...}: {
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

      effort = lib.mkOption {
        type = lib.types.nullOr (lib.types.enum ["low" "medium" "high" "max"]);
        default = null;
        description = "Preferred reasoning effort for tools that support per-skill effort selection.";
      };

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
    };
  });

  mcpServerType = lib.types.submodule ({name, ...}: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        readOnly = true;
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
    };
  });

  lspServerType = lib.types.submodule ({name, ...}: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        readOnly = true;
        description = "LSP server name.";
      };

      description = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Short description of the LSP server.";
      };

      command = lib.mkOption {
        type = lib.types.str;
        description = "Executable used to launch the LSP server.";
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
        description = "Mapping from file extension to language identifier.";
      };

      startupTimeout = lib.mkOption {
        type = lib.types.nullOr lib.types.int;
        default = null;
        description = "Optional startup timeout in milliseconds.";
      };
    };
  });

  agentType = lib.types.submodule ({name, ...}: {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        default = name;
        readOnly = true;
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
        description = "Tool names the agent should be allowed or expected to use.";
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
        description = "Preferred model for tools that support per-agent model selection.";
      };

      color = lib.mkOption {
        type = lib.types.nullOr lib.types.str;
        default = null;
        description = "Display color for tools that support agent color metadata.";
      };
    };
  });

  sharedProfileOptions = {
    instructions = lib.mkOption {
      type = textSourceType;
      default = {};
      description = "Inline instructions or a source file shared across coding tools.";
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf mcpServerType;
      default = {};
      description = "Shared MCP server definitions.";
    };

    lspServers = lib.mkOption {
      type = lib.types.attrsOf lspServerType;
      default = {};
      description = "Shared LSP server definitions.";
    };

    agents = lib.mkOption {
      type = lib.types.attrsOf agentType;
      default = {};
      description = "Shared structured agent definitions.";
    };

    commands = lib.mkOption {
      type = lib.types.attrsOf commandType;
      default = {};
      description = "Shared structured command definitions.";
    };

    skills = lib.mkOption {
      type = lib.types.attrsOf skillType;
      default = {};
      description = "Shared structured skill definitions.";
    };

    rules = lib.mkOption {
      type = lib.types.attrsOf ruleType;
      default = {};
      description = "Shared structured rules that guide coding tools.";
    };
  };

  profileModule = {name, ...}: {
    options =
      sharedProfileOptions
      // {
        description = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "Everyday development";
          description = "Short description of the profile.";
        };

        extends = lib.mkOption {
          type = lib.types.nullOr (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
          default = null;
          example = ["default" "monitoring"];
          description = "Profile or profiles to extend.";
        };

        include = lib.mkOption {
          type = lib.types.listOf lib.types.attrs;
          default = [];
          description = "Addon configs (shared-profile shape) merged into this profile. Profile-own content wins on conflicts.";
        };

        name = lib.mkOption {
          type = lib.types.str;
          default = name;
          readOnly = true;
          description = "Profile name.";
        };
      };
  };

  resolvedProfileOptions =
    sharedProfileOptions
    // {
      description = lib.mkOption {
        type = lib.types.str;
        default = "";
        description = "Resolved profile description.";
      };

      name = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Resolved profile name.";
      };
    };

  profileType = lib.types.submodule profileModule;
  resolvedProfileType = lib.types.submodule {options = resolvedProfileOptions;};
in {
  inherit
    agentType
    commandType
    lspServerType
    mcpServerType
    profileType
    resolvedProfileType
    ruleType
    sharedProfileOptions
    skillType
    textSourceOptions
    textSourceType
    ;
}
