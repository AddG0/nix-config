# Writes the default profile's Codex render to programs.codex and home.file, and every other profile as a layered profile file.
{customLib, ...}: {
  config,
  lib,
  pkgs,
  ...
}: let
  codingCfg = config.programs.code-assistant-profiles;
  codexHooks = import ./hooks.nix {
    inherit lib;
    inherit (customLib) mkHookSchema;
  };

  # $CODEX_HOME/skills is deprecated upstream; ~/.agents/skills is the user root.
  skillsRelative = ".agents/skills";
  codexHomeRelative = lib.removePrefix "/" (import ../../../codex/codex-home.nix {inherit config lib;});

  renderOver = base:
    import ./render.nix {
      inherit base codexHooks customLib lib pkgs;
      inherit (codingCfg.targets.codex) hooks;
      skillsDir = "${config.home.homeDirectory}/${skillsRelative}";
    };
  render = renderOver null;

  profileName = codingCfg.defaultProfile;
  hasProfile = codingCfg.enable && builtins.hasAttr profileName codingCfg.resolved;
  profile = codingCfg.resolved.${profileName};
  rendered = render profile;

  checkable = lib.filterAttrs (name: _: codingCfg.fieldTypeProblems.${name} == []) codingCfg.resolved;

  otherProfiles = removeAttrs codingCfg.resolved [profileName];
  profileFile = layered:
    lib.optionalAttrs (layered.mcpServers != {}) {mcp_servers = layered.mcpServers;}
    // lib.optionalAttrs (layered.instructions != "") {developer_instructions = layered.instructions;};
  profileFiles = lib.mapAttrs (_: other: profileFile (renderOver profile other)) otherProfiles;
  writtenProfiles = lib.filterAttrs (_: file: file != {}) profileFiles;
  emptyProfiles = lib.attrNames (lib.filterAttrs (_: file: file == {}) profileFiles);

  prefixed = prefix: lib.mapAttrs' (path: lib.nameValuePair "${prefix}/${path}");

  writesProfile = codingCfg.targets.codex.enable && hasProfile;
in {
  imports = [(import ./options.nix {inherit codexHooks lib;})];

  # Not under the mkIf: its condition reads `targets`, which this definition is part of.
  config = lib.mkMerge [
    {
      programs.code-assistant-profiles.targets.codex.writtenSkillNames =
        lib.optionals (writesProfile && config.programs.codex.enable)
        (lib.attrValues (lib.mapAttrs (name: _: name) profile.commands // lib.mapAttrs (_: skill: skill.name) profile.skills));
    }

    (lib.mkIf (codingCfg.enable && !codingCfg.targets.codex.enable && codingCfg.targets.codex.hooks != {}) {
      warnings = ["programs.code-assistant-profiles.targets.codex.hooks is set, but programs.code-assistant-profiles.targets.codex.enable is false, so no Codex hook is written"];
    })

    (lib.mkIf (codingCfg.enable && codingCfg.targets.codex.enable) {
      programs.code-assistant-profiles.droppedFields.codex = lib.mapAttrs (_: other: (render other).dropped) checkable;
    })

    (lib.mkIf writesProfile {
      programs.codex =
        {
          enable = lib.mkDefault true;
          context = rendered.instructions;
          settings = lib.optionalAttrs (rendered.mcpServers != {}) {mcp_servers = rendered.mcpServers;};
          profiles = writtenProfiles;
        }
        // lib.optionalAttrs (rendered.hooks != {}) {inherit (rendered) hooks;};

      warnings =
        map (name: "programs.code-assistant-profiles.profiles.\"${name}\": a Codex profile carries only MCP servers and instructions, and these match \"${profileName}\"'s, so the codex target writes no `${name}` profile and `codex --profile ${name}` cannot select it")
        emptyProfiles;

      assertions =
        map (problem: {
          assertion = false;
          message = "programs.code-assistant-profiles.targets.codex.hooks: ${problem}";
        }) (codexHooks.problems codingCfg.targets.codex.hooks)
        ++ lib.mapAttrsToList (name: _: {
          assertion = builtins.match "[A-Za-z0-9_-]+" name != null;
          message = "programs.code-assistant-profiles.profiles.\"${name}\": Codex `--profile` accepts only letters, digits, `-` and `_`, so the codex target cannot select it";
        })
        otherProfiles;

      home.file = lib.mkIf config.programs.codex.enable (
        prefixed skillsRelative (rendered.commands // rendered.skills)
        // prefixed "${codexHomeRelative}/agents" rendered.agents
      );
    })
  ];
}
