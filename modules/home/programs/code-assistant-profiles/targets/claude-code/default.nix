# Renders every resolved shared profile into programs.claude-code-profiles, beneath each Claude profile's own config.
{customLib, ...}: {
  config,
  lib,
  pkgs,
  ...
}: let
  codingCfg = config.programs.code-assistant-profiles;

  claudeSettingsHooks = import ../../../claude-code/settings-hooks.nix {
    inherit lib;
    inherit (customLib) mkHookSchema;
  };

  render = import ./render.nix {
    inherit claudeSettingsHooks customLib lib pkgs;
  };

  validation = import ./validation.nix {
    inherit claudeSettingsHooks lib;
  };

  # A profile whose fields fail their type is already reported, and reading it would throw.
  checkable = lib.filterAttrs (name: _: codingCfg.fieldTypeProblems.${name} == []) codingCfg.resolved;

  profileDefaults = profile: let
    rendered = render profile;
  in {
    inherit (profile) description;
    memory = rendered.instructions;
    inherit (rendered) rules agents skills commands mcpServers lspServers;
  };
in {
  config = lib.mkMerge [
    {programs.code-assistant-profiles.validators.claude-code = import ./validator.nix {inherit config lib;};}

    (lib.mkIf (codingCfg.enable && codingCfg.targets.claude-code.enable) {
      programs.claude-code-profiles = {
        enable = lib.mkDefault true;
        profileDefaults = lib.mapAttrs (_: profileDefaults) codingCfg.resolved;
      };

      programs.code-assistant-profiles.droppedFields.claude-code = lib.mapAttrs (_: profile: (render profile).dropped) checkable;

      assertions = lib.concatLists (lib.mapAttrsToList (name: profile:
        map (message: {
          assertion = false;
          inherit message;
        }) (validation.frontmatterHookProblems "profile '${name}'" profile))
      checkable);
    })
  ];
}
