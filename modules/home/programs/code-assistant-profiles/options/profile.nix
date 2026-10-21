# Profile layering: what a layer declares, and the resolved profile every target reads.
{lib}: let
  inherit (import ./fields.nix {inherit lib;}) textSourceType;

  entryTypes = {
    agents = import ./agent.nix {inherit lib;};
    commands = import ./command.nix {inherit lib;};
    skills = import ./skill.nix {inherit lib;};
    rules = import ./rule.nix {inherit lib;};
    mcpServers = import ./mcp-server.nix {inherit lib;};
    lspServers = import ./lsp-server.nix {inherit lib;};
  };

  profileContentOptions = {
    instructions = lib.mkOption {
      type = textSourceType;
      default = {};
      description = "Inline instructions or a source file shared across coding tools.";
    };

    mcpServers = lib.mkOption {
      type = lib.types.attrsOf entryTypes.mcpServers;
      default = {};
      description = "Shared MCP server definitions. Each entry follows options/mcp-server.nix.";
    };

    lspServers = lib.mkOption {
      type = lib.types.attrsOf entryTypes.lspServers;
      default = {};
      description = "Shared LSP server definitions. Each entry follows options/lsp-server.nix.";
    };

    agents = lib.mkOption {
      type = lib.types.attrsOf entryTypes.agents;
      default = {};
      description = "Shared structured agent definitions. Each entry follows options/agent.nix.";
    };

    commands = lib.mkOption {
      type = lib.types.attrsOf entryTypes.commands;
      default = {};
      description = "Shared structured command definitions. Each entry follows options/command.nix.";
    };

    skills = lib.mkOption {
      type = lib.types.attrsOf entryTypes.skills;
      default = {};
      description = "Shared structured skill definitions. Each entry follows options/skill.nix.";
    };

    rules = lib.mkOption {
      type = lib.types.attrsOf entryTypes.rules;
      default = {};
      description = "Shared structured rules that guide coding tools. Each entry follows options/rule.nix.";
    };
  };

  # Merged raw so a layer overrides only the fields it sets (`resolved` types each entry once); option docs still see the fields.
  declaredEntriesOption = typedOption:
    lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf lib.types.anything // {inherit (typedOption.type.nestedTypes.elemType) getSubOptions;});
      default = {};
      inherit (typedOption) description;
    };

  declaredProfileOptions =
    profileContentOptions
    // lib.mapAttrs (_: declaredEntriesOption) (removeAttrs profileContentOptions ["instructions"]);

  profileModule = {name, ...}: {
    options =
      declaredProfileOptions
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
          description = "Profile name.";
        };
      };
  };

  resolvedProfileOptions =
    profileContentOptions
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

      instructionSections = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        internal = true;
        description = "The non-empty instructions of each layer (baseConfig, parents, includes, the profile), in merge order; `instructions` is these joined by a blank line.";
      };
    };
in {
  inherit declaredProfileOptions entryTypes profileContentOptions;
  profileType = lib.types.submodule profileModule;
  resolvedProfileType = lib.types.submodule {options = resolvedProfileOptions;};
}
