{
  claudeSettingsHooks,
  lib,
  pkgs,
  pluginCheck,
  resolvedProfiles,
}: let
  jsonFormat = pkgs.formats.json {};

  renderSettings = settings: let
    hooks = claudeSettingsHooks.render (settings.hooks or {});
  in
    removeAttrs settings ["hooks"] // lib.optionalAttrs (hooks != {}) {inherit hooks;};

  # Claude watches the directory a symlinked settings file resolves into; a top-level store file makes that all of /nix/store.
  settingsFile = settings: let
    json = jsonFormat.generate "claude-settings.json" (
      settings // {"$schema" = "https://json.schemastore.org/claude-code-settings.json";}
    );
  in "${pkgs.runCommand "claude-settings" {} "mkdir $out && cp ${json} $out/settings.json"}/settings.json";

  mkFileEntry = content:
    if lib.isPath content || lib.isDerivation content
    then {source = content;}
    else {text = content;};

  # The manifest's build validates the whole plugin, so a plugin Claude Code rejects never links.
  lspManifest = name: servers: let
    manifest = jsonFormat.generate "claude-lsp-plugin.json" {
      name = "lsp";
      description = "Language servers declared in Nix.";
    };
  in
    pkgs.runCommand "claude-lsp-plugin-${name}.json" {} ''
      mkdir -p plugin/.claude-plugin
      cp ${jsonFormat.generate "claude-lsp.json" servers} plugin/.lsp.json
      cp ${manifest} plugin/.claude-plugin/plugin.json
      ${pluginCheck.validate "plugin"}
      cp ${manifest} "$out"
    '';

  mkProfileFiles = name: profile: let
    inherit (profile) profileDir;
    finalConfig = resolvedProfiles.${name};
    settings = renderSettings finalConfig.settings;
  in
    lib.optionalAttrs (settings != {}) {
      "${profileDir}/settings.json".source = settingsFile settings;
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
      # Optional for --plugin-dir, but `claude plugin validate` rejects a plugin without one.
      "${profileDir}/plugins/lsp/.claude-plugin/plugin.json".source = lspManifest name finalConfig.lspServers;
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
      scriptName: content:
        lib.nameValuePair "${profileDir}/hooks/${scriptName}" {
          text = content;
          executable = true;
        }
    )
    finalConfig.hookScripts
    // lib.mapAttrs' (
      skillName: content: let
        isDir =
          if lib.isDerivation content
          then true
          else if lib.isPath content
          then lib.pathIsDirectory content
          else false;
      in
        if isDir
        then
          # Skills are read-only, so one link per skill beats one per file.
          lib.nameValuePair "${profileDir}/skills/${skillName}" {
            source = content;
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
  inherit mkFileEntry mkProfileFiles renderSettings;
}
