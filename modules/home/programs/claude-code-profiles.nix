# ==============================================================================
# Claude Code Profiles Module
# ==============================================================================
#
# Manage multiple isolated Claude Code configurations using named profiles.
# Each profile maintains its own settings, memory, MCP servers, agents, skills,
# commands, hooks, and rules.
#
# USAGE:
#   programs.claude-code-profiles = {
#     enable = true;
#     defaultProfile = "default";
#
#     # Base configuration merged into all profiles
#     baseConfig = {
#       settings.theme = "dark";
#       memory.text = "Always be helpful and concise.";
#       mcpServers.context7 = { command = "context7-mcp"; };
#     };
#
#     # Profile definitions
#     profiles = {
#       default = {
#         settings.permissions.allow = [ "Bash(npm test)" ];
#       };
#       grafana = {
#         mcpServers.grafana = { command = "mcp-grafana"; };
#         settings.env.GRAFANA_URL = "https://grafana.example.com";
#         memory.text = "You are a Grafana specialist.";
#       };
#     };
#   };
#
# CLI:
#   claude                    # Uses default profile
#   claude --profile grafana  # Uses grafana profile
#   claude -P grafana         # Short form (-p is reserved for --print)
#   claude --list-profiles    # List available profiles
#
# ==============================================================================
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.claude-code-profiles;
  jsonFormat = pkgs.formats.json {};
  baseDir = ".config/claude-code/profiles";

  # Check if content represents a file path (handles both path types and string paths).
  # Guards against calling pathExists on arbitrary content strings.
  isPathContent = content:
    lib.isPath content
    || (lib.isString content
      && (lib.hasPrefix "/" content || lib.hasPrefix "./" content)
      && builtins.pathExists content);

  # Convert content to a home.file entry based on its type.
  mkFileEntry = content:
    if isPathContent content
    then {source = content;}
    else {text = content;};

  # Shared options for baseConfig and profile configurations
  configOptions = {
    settings = lib.mkOption {
      inherit (jsonFormat) type;
      default = {};
      description = "Claude Code settings (theme, permissions, environment variables, etc.).";
    };

    memory = {
      text = lib.mkOption {
        type = lib.types.nullOr lib.types.lines;
        default = null;
        description = "Inline instructions for Claude, written to CLAUDE.md.";
      };

      source = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a file containing instructions for Claude.";
      };
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf jsonFormat.type;
      default = {};
      description = "MCP server definitions for this configuration.";
    };

    agents = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.lines lib.types.path);
      default = {};
      description = "Custom agent definitions (inline text or path to file).";
    };

    commands = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.lines lib.types.path);
      default = {};
      description = "Custom slash commands (inline text or path to file).";
    };

    hooks = lib.mkOption {
      type = lib.types.attrsOf lib.types.lines;
      default = {};
      description = "Shell scripts triggered on Claude Code events.";
    };

    skills = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.lines lib.types.path);
      default = {};
      description = "Reusable skill definitions (inline text, file path, or directory).";
    };

    rules = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.lines lib.types.path);
      default = {};
      description = "Project rules that guide Claude's behavior.";
    };
  };

  # Profile submodule with computed profileDir and extends
  profileModule = {name, ...}: {
    options =
      configOptions
      // {
        description = lib.mkOption {
          type = lib.types.str;
          default = "";
          example = "Everyday development";
          description = "Short description shown in shell completions.";
        };

        extends = lib.mkOption {
          type = lib.types.nullOr (lib.types.either lib.types.str (lib.types.listOf lib.types.str));
          default = null;
          example = ["default" "monitoring"];
          description = "Profile(s) to extend. Can be a single name or list of names.";
        };

        profileDir = lib.mkOption {
          type = lib.types.str;
          default = "${baseDir}/${name}";
          readOnly = true;
          description = "Configuration directory for this profile (relative to $HOME).";
        };
      };
  };

  # Merge two configs (base into overlay)
  mergeConfigs = base: overlay: {
    settings = lib.recursiveUpdate (base.settings or {}) (overlay.settings or {});
    memory = let
      texts = lib.filter (t: t != null) [(base.memory.text or null) (overlay.memory.text or null)];
    in {
      text =
        if texts != []
        then lib.concatStringsSep "\n\n" texts
        else null;
      source = overlay.memory.source or base.memory.source or null;
    };
    mcpServers = (base.mcpServers or {}) // (overlay.mcpServers or {});
    agents = (base.agents or {}) // (overlay.agents or {});
    commands = (base.commands or {}) // (overlay.commands or {});
    hooks = (base.hooks or {}) // (overlay.hooks or {});
    skills = (base.skills or {}) // (overlay.skills or {});
    rules = (base.rules or {}) // (overlay.rules or {});
  };

  # Resolve profile extension chain (supports single string or list)
  resolveProfile = name: profile:
    if profile.extends == null
    then profile
    else let
      extendsList =
        if lib.isList profile.extends
        then profile.extends
        else [profile.extends];
      resolveOne = parentName: let
        parent = cfg.profiles.${parentName} or (throw "Profile '${name}' extends unknown profile '${parentName}'");
      in
        resolveProfile parentName parent;
      resolved = lib.foldl mergeConfigs {} (map resolveOne extendsList);
    in
      mergeConfigs resolved profile;

  # Merge: baseConfig → resolved profile
  mergeWithBase = name: profile: let
    resolved = resolveProfile name profile;
  in
    mergeConfigs cfg.baseConfig resolved;

  # Generate home.file entries for a profile
  mkProfileFiles = name: profile: let
    inherit (profile) profileDir;
    finalConfig = mergeWithBase name profile;
  in
    lib.optionalAttrs (finalConfig.settings != {}) {
      "${profileDir}/settings.json".source = jsonFormat.generate "claude-settings.json" (
        finalConfig.settings // {"$schema" = "https://json.schemastore.org/claude-code-settings.json";}
      );
    }
    // lib.optionalAttrs (finalConfig.memory.text != null) {
      "${profileDir}/CLAUDE.md".text = finalConfig.memory.text;
    }
    // lib.optionalAttrs (finalConfig.memory.source != null) {
      "${profileDir}/CLAUDE.md".source = finalConfig.memory.source;
    }
    // lib.optionalAttrs (finalConfig.mcpServers != {}) {
      "${profileDir}/.mcp.json".source = jsonFormat.generate "claude-mcp.json" {
        inherit (finalConfig) mcpServers;
      };
    }
    // lib.mapAttrs' (
      agentName: content:
        lib.nameValuePair "${profileDir}/agents/${agentName}.md" (mkFileEntry content)
    )
    finalConfig.agents
    // lib.mapAttrs' (
      cmdName: content:
        lib.nameValuePair "${profileDir}/commands/${cmdName}.md" (mkFileEntry content)
    )
    finalConfig.commands
    // lib.mapAttrs' (
      hookName: content:
        lib.nameValuePair "${profileDir}/hooks/${hookName}" {
          text = content;
          executable = true;
        }
    )
    finalConfig.hooks
    // lib.mapAttrs' (
      skillName: content: let
        isDir =
          if lib.isPath content
          then lib.pathIsDirectory content
          else if isPathContent content
          then (builtins.readFileType content) == "directory"
          else false;
      in
        if isDir
        then
          lib.nameValuePair "${profileDir}/skills/${skillName}" {
            source = content;
            recursive = true;
          }
        else lib.nameValuePair "${profileDir}/skills/${skillName}.md" (mkFileEntry content)
    )
    finalConfig.skills
    // lib.mapAttrs' (
      ruleName: content:
        lib.nameValuePair "${profileDir}/rules/${ruleName}.md" (mkFileEntry content)
    )
    finalConfig.rules;

  # Zsh completion package (installed to ~/.nix-profile/share/zsh/site-functions)
  zshCompletion = pkgs.runCommand "claude-zsh-completion" {} ''
        mkdir -p $out/share/zsh/site-functions
        cat > $out/share/zsh/site-functions/_claude << 'COMPLETION'
    #compdef claude

    # Profile completions with descriptions
    _claude_profiles() {
      local -a profiles
      profiles=(${lib.concatStringsSep " " (lib.mapAttrsToList (
        name: profile: let
          desc =
            if profile.description != ""
            then profile.description
            else name;
        in "'${name}:${desc}'"
      )
      cfg.profiles)})
      _describe 'profile' profiles
    }

    # Main upstream completion logic (inline to avoid fetch complexity)
    _claude_main() {
      local curcontext="$curcontext" state line
      typeset -A opt_args

      local -a commands
      commands=(
        'doctor:Check the health of your Claude Code auto-updater'
        'install:Install Claude Code native build'
        'mcp:Configure and manage MCP servers'
        'plugin:Manage Claude Code plugins'
        'setup-token:Set up a long-lived authentication token'
        'update:Check for updates and install if available'
      )

      _arguments -C \
        '(-P --profile)'{-P,--profile}'[Use a specific profile]:profile:_claude_profiles' \
        '--list-profiles[List available profiles]' \
        '(-p --print)'{-p,--print}'[Print response without interactive mode]' \
        '(-c --continue)'{-c,--continue}'[Continue most recent conversation]' \
        '--resume[Resume a specific conversation by session ID]:session_id:' \
        '(-v --verbose)'{-v,--verbose}'[Enable verbose logging]' \
        '--dangerously-skip-permissions[Skip permission checks]' \
        '--allowedTools[Comma-separated list of allowed tools]:tools:' \
        '--disallowedTools[Comma-separated list of disallowed tools]:tools:' \
        '--mcp-config[Path to MCP config file]:file:_files' \
        '--permission-mode[Permission mode]:mode:(default acceptEdits bypassPermissions)' \
        '(-m --model)'{-m,--model}'[Model to use]:model:' \
        '--max-turns[Max conversation turns]:turns:' \
        '--version[Show version]' \
        '(-h --help)'{-h,--help}'[Display help]' \
        '1: :->cmds' \
        '*::arg:->args'

      case $state in
        cmds)
          _describe 'command' commands
          _files
          ;;
        args)
          case $words[1] in
            mcp)
              local -a mcp_commands
              mcp_commands=(
                'add:Add an MCP server'
                'list:List configured MCP servers'
                'remove:Remove an MCP server'
                'serve:Start the Claude Code MCP server'
              )
              _describe 'mcp command' mcp_commands
              ;;
            plugin)
              local -a plugin_commands
              plugin_commands=(
                'install:Install a plugin'
                'list:List installed plugins'
                'uninstall:Uninstall a plugin'
                'enable:Enable a plugin'
                'disable:Disable a plugin'
              )
              _describe 'plugin command' plugin_commands
              ;;
            *)
              _files
              ;;
          esac
          ;;
      esac
    }

    _claude() {
      _claude_main "$@"
    }
    COMPLETION
  '';

  # Profile-aware wrapper script
  wrapperScript = pkgs.writeShellScriptBin "claude" ''
    PROFILE="${cfg.defaultProfile}"
    ARGS=()

    while [[ $# -gt 0 ]]; do
      case "$1" in
        --profile|-P)
          if [[ -n "$2" && ! "$2" =~ ^- ]]; then
            PROFILE="$2"
            shift 2
          else
            echo "Error: --profile requires a profile name" >&2
            exit 1
          fi
          ;;
        --profile=*) PROFILE="''${1#--profile=}"; shift ;;
        -P=*) PROFILE="''${1#-P=}"; shift ;;
        --list-profiles)
          echo "Available profiles:"
          for dir in "$HOME/${baseDir}"/*/; do
            [ -d "$dir" ] && echo "  - $(basename "$dir")"
          done
          exit 0
          ;;
        *) ARGS+=("$1"); shift ;;
      esac
    done

    PROFILE_DIR="$HOME/${baseDir}/$PROFILE"

    if [[ ! -d "$PROFILE_DIR" ]]; then
      echo "Error: Profile '$PROFILE' not found at $PROFILE_DIR" >&2
      echo "Available profiles:"
      for dir in "$HOME/${baseDir}"/*/; do
        [ -d "$dir" ] && echo "  - $(basename "$dir")"
      done
      exit 1
    fi

    export CLAUDE_CONFIG_DIR="$PROFILE_DIR"

    # Load MCP servers via CLI flag (required since Claude doesn't read .mcp.json from CLAUDE_CONFIG_DIR)
    MCP_ARGS=()
    if [[ -f "$PROFILE_DIR/.mcp.json" ]]; then
      MCP_ARGS+=(--mcp-config "$PROFILE_DIR/.mcp.json")
    fi

    exec ${cfg.package}/bin/claude "''${MCP_ARGS[@]}" "''${ARGS[@]}"
  '';
in {
  options.programs.claude-code-profiles = {
    enable = lib.mkEnableOption "Claude Code with profile-based configuration management";

    package = lib.mkPackageOption pkgs "claude-code" {nullable = true;};

    defaultProfile = lib.mkOption {
      type = lib.types.str;
      default = "default";
      description = "Profile to use when --profile is not specified.";
    };

    baseConfig = lib.mkOption {
      type = lib.types.submodule {options = configOptions;};
      default = {};
      description = "Base configuration merged into all profiles.";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule profileModule);
      default = {};
      description = "Named profile configurations.";
    };

    enableZshIntegration = lib.mkEnableOption "Zsh completions for Claude Code" // {default = false;};
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.profiles != {};
        message = "At least one profile must be defined in programs.claude-code-profiles.profiles";
      }
      {
        assertion = cfg.profiles ? ${cfg.defaultProfile};
        message = "Default profile '${cfg.defaultProfile}' must exist in programs.claude-code-profiles.profiles";
      }
    ];

    home.packages = [wrapperScript] ++ lib.optional cfg.enableZshIntegration zshCompletion;

    home.file = lib.foldl' (
      acc: name: acc // mkProfileFiles name cfg.profiles.${name}
    ) {} (lib.attrNames cfg.profiles);
  };
}
