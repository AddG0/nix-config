{
  baseDir,
  lib,
  pkgs,
}: let
  jsonFormat = pkgs.formats.json {};

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

    lspServers = lib.mkOption {
      type = lib.types.attrsOf jsonFormat.type;
      default = {};
      description = "LSP server definitions for code intelligence.";
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

    outputStyles = lib.mkOption {
      type = lib.types.attrsOf (lib.types.either lib.types.lines lib.types.path);
      default = {};
      example = lib.literalExpression ''
        {
          concise = '''
            ---
            name: Concise
            description: Short, direct responses
            keep-coding-instructions: true
            ---

            Be extremely concise. No filler words.
          ''';
          reviewer = ./output-styles/reviewer.md;
        }
      '';
      description = "Custom output style definitions (Markdown with frontmatter, inline text or path to file).";
    };

    pluginDirs = lib.mkOption {
      type = lib.types.listOf (lib.types.either lib.types.path lib.types.str);
      default = [];
      description = "Plugin directories to load via --plugin-dir.";
    };

    extraFiles = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      default = {};
      example = lib.literalExpression ''
        {
          "plugins/claude-hud/config.json".source = jsonFormat.generate "hud.json" { ... };
          "some-file.txt".text = "hello";
        }
      '';
      description = "Extra files to place in the profile directory. Keys are relative paths, values are home.file-compatible attrsets ({ source = ...; } or { text = ...; }).";
    };
  };

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
in {
  inherit configOptions profileModule;

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

    resolved = lib.mkOption {
      type = lib.types.attrsOf lib.types.attrs;
      readOnly = true;
      internal = true;
      description = "Fully resolved profile configs (baseConfig + extends + profile). Read-only.";
    };
  };
}
