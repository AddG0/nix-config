# Writes the default profile's opencode render to programs.opencode and xdg.configFile.
{customLib, ...}: {
  config,
  lib,
  pkgs,
  ...
}: let
  codingCfg = config.programs.code-assistant-profiles;

  render = import ./render.nix {
    inherit customLib lib pkgs;
    inherit (codingCfg.targets.opencode) plugins;
    codexSkillNames = codingCfg.targets.codex.writtenSkillNames;
    skillsDir = "${config.xdg.configHome}/opencode/skills";
  };

  profileName = codingCfg.defaultProfile;
  hasProfile = codingCfg.enable && builtins.hasAttr profileName codingCfg.resolved;
  rendered = render codingCfg.resolved.${profileName};

  checkable = lib.filterAttrs (name: _: codingCfg.fieldTypeProblems.${name} == []) codingCfg.resolved;

  textSkills = lib.filterAttrs (_: skill: lib.isString skill) rendered.skills.definitions;
  skillDirectories = lib.filterAttrs (_: skill: !(lib.isString skill)) rendered.skills.definitions;
in {
  imports = [./options.nix];

  config = lib.mkMerge [
    (lib.mkIf (codingCfg.enable && codingCfg.targets.opencode.enable) {
      programs.code-assistant-profiles.droppedFields.opencode = lib.mapAttrs (_: profile: (render profile).dropped) checkable;
    })

    (lib.mkIf (codingCfg.targets.opencode.enable && hasProfile) {
      programs.opencode = {
        enable = lib.mkDefault true;
        agents = lib.mkDefault rendered.agents;
        commands = lib.mkDefault rendered.commands;
        skills = lib.mkDefault textSkills;
        context = lib.mkDefault rendered.instructions;
        settings =
          {
            mcp = lib.mkDefault rendered.mcpServers;
            lsp = lib.mkDefault rendered.lspServers;
          }
          // lib.optionalAttrs (rendered.skills.permission != {}) {permission.skill = rendered.skills.permission;};
      };

      xdg.configFile =
        lib.mapAttrs' (name: skill: lib.nameValuePair "opencode/skills/${name}" {source = skill;}) skillDirectories
        // lib.mapAttrs' (name: lib.nameValuePair "opencode/plugins/${name}") rendered.hooks;

      assertions =
        lib.mapAttrsToList (name: _: {
          assertion = builtins.match ".+\\.(js|ts)" name != null;
          message = "programs.code-assistant-profiles.targets.opencode.plugins.\"${name}\" must end in .js or .ts; opencode loads only those from opencode/plugins/";
        })
        codingCfg.targets.opencode.plugins;
    })
  ];
}
