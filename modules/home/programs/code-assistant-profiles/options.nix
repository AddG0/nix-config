{
  lib,
  pkgs,
  typesModule,
}: {
  options.programs.code-assistant-profiles = {
    enable = lib.mkEnableOption "shared profile-based configuration for coding tools";

    defaultProfile = lib.mkOption {
      type = lib.types.str;
      default = "default";
      description = "Default shared profile name.";
    };

    baseConfig = lib.mkOption {
      type = lib.types.submodule {options = typesModule.sharedProfileOptions;};
      default = {};
      description = "Base shared configuration merged into all profiles by future adapters.";
    };

    addons = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule {options = typesModule.sharedProfileOptions;});
      default = {};
      description = "Named, reusable shared-profile content blocks that profiles can include via the `include` option.";
    };

    profiles = lib.mkOption {
      type = lib.types.attrsOf typesModule.profileType;
      default = {};
      description = "Named shared profile definitions for coding tools.";
    };

    targets = lib.mkOption {
      type = lib.types.submodule {
        options = {
          claude-code.enable = lib.mkEnableOption "rendering shared profiles for Claude Code (drives programs.claude-code-profiles.enable)";
          opencode.enable = lib.mkEnableOption "rendering shared profiles for opencode (drives programs.opencode.enable)";
        };
      };
      default = {};
      description = "Per-tool rendering target toggles. Enable each target to flow shared profiles into the corresponding tool module.";
    };

    resolved = lib.mkOption {
      type = lib.types.attrsOf typesModule.resolvedProfileType;
      readOnly = true;
      internal = true;
      description = "Fully resolved profile configs after applying baseConfig and extends.";
    };
  };
}
