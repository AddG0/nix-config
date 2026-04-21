{
  lib,
  pkgs,
  resolvedProfiles,
}: let
  jsonFormat = pkgs.formats.json {};

  isPathContent = content:
    lib.isPath content
    || lib.isDerivation content
    || (lib.isString content
      && (lib.hasPrefix "/" content || lib.hasPrefix "./" content)
      && builtins.pathExists content);

  mkFileEntry = content:
    if isPathContent content
    then {source = content;}
    else {text = content;};

  mkProfileFiles = name: profile: let
    inherit (profile) profileDir;
    finalConfig = resolvedProfiles.${name};
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
    // lib.optionalAttrs (finalConfig.lspServers != {}) {
      "${profileDir}/plugins/lsp/.lsp.json".source =
        jsonFormat.generate "claude-lsp.json" finalConfig.lspServers;
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
          if lib.isDerivation content
          then true
          else if lib.isPath content
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
        else lib.nameValuePair "${profileDir}/skills/${skillName}/SKILL.md" (mkFileEntry content)
    )
    finalConfig.skills
    // lib.mapAttrs' (
      ruleName: content:
        lib.nameValuePair "${profileDir}/rules/${ruleName}.md" (mkFileEntry content)
    )
    finalConfig.rules
    // lib.mapAttrs' (
      styleName: content:
        lib.nameValuePair "${profileDir}/output-styles/${styleName}.md" (mkFileEntry content)
    )
    finalConfig.outputStyles
    // lib.mapAttrs' (
      relPath: attrs:
        lib.nameValuePair "${profileDir}/${relPath}" attrs
    )
    finalConfig.extraFiles;
in {
  inherit isPathContent mkFileEntry mkProfileFiles;
}
