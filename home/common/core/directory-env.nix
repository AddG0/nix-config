# Directory-scoped environment variables (zsh). Each rule exports its `env`
# while $PWD is at or under any of its `paths`, and unsets those vars on leaving
# — via zsh's chpwd_functions (the hook direnv uses), independent of .envrc.
# Generic by design; concrete paths/secrets live in the consuming config.
{
  config,
  lib,
  ...
}: let
  cfg = config.programs.directoryEnv;

  ruleBlock = i: rule: let
    marker = "_DIRECTORY_ENV_${toString i}";
    # "$PWD/" vs "$p"/* matches both $p itself and anything under it, while a
    # sibling like "${p}foo" can't sneak through.
    match = lib.concatMapStringsSep " || " (p: ''[[ "$PWD/" == "${lib.removeSuffix "/" p}"/* ]]'') rule.paths;
    exports = lib.concatStringsSep "\n    " (lib.mapAttrsToList (n: v: ''export ${n}="${v}"'') rule.env);
    unsets = lib.concatStringsSep " " (lib.attrNames rule.env ++ [marker]);
  in ''
    if ${match}; then
      ${exports}
      export ${marker}=1
    elif [[ -n "''${${marker}}" ]]; then
      unset ${unsets}
    fi
  '';
in {
  options.programs.directoryEnv = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = cfg.rules != [];
      description = "Export env vars scoped to directory trees (zsh). On by default when rules are set.";
    };

    rules = lib.mkOption {
      default = [];
      description = ''
        Each rule exports `env` while $PWD is at or under any of `paths`, and
        unsets those vars on leaving. Values are shell-expanded at runtime, so
        they may reference $HOME, command substitutions, etc.
      '';
      type = lib.types.listOf (lib.types.submodule {
        options = {
          paths = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            description = "Directory paths; the rule applies at or under any of them.";
          };
          env = lib.mkOption {
            type = lib.types.attrsOf lib.types.str;
            description = "Environment variables to export within the paths.";
          };
        };
      });
    };
  };

  # One chpwd handler runs every rule; registered once, fired once on init.
  config = lib.mkIf (cfg.enable && cfg.rules != []) {
    programs.zsh.initContent = lib.mkAfter ''
      _directory_env() {
      ${lib.concatStringsSep "\n" (lib.imap0 ruleBlock cfg.rules)}
      }
      typeset -ag chpwd_functions
      (( ''${chpwd_functions[(I)_directory_env]} )) || chpwd_functions=(_directory_env $chpwd_functions)
      _directory_env
    '';
  };
}
