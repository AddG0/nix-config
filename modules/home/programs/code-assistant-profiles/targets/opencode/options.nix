{lib, ...}: {
  options.programs.code-assistant-profiles.targets = lib.mkOption {
    type = lib.types.submodule {
      options.opencode.plugins = lib.mkOption {
        type = lib.types.attrsOf (lib.types.either lib.types.lines lib.types.path);
        default = {};
        example = lib.literalExpression ''{"notify.js" = ./plugins/notify.js;}'';
        description = ''
          Local opencode plugins, file name (ending `.js` or `.ts`) to module
          source as inline text or a path. Each is written to
          {file}`$XDG_CONFIG_HOME/opencode/plugins/<name>`, file by file, so
          plugins other modules place there stay.

          These are global, like Codex hooks: opencode renders only the default
          profile. Claude Code hooks are set per profile.
        '';
      };
    };
  };
}
