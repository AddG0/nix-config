# Environment variables scoped to directory trees — declarative rules, not direnv's .envrc.
{
  config,
  lib,
  pkgs,
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

  ruleBlocks = lib.concatStringsSep "\n" (lib.imap0 ruleBlock cfg.rules);
in {
  options.programs.directoryEnv = {
    enableZshIntegration = lib.mkOption {
      type = lib.types.bool;
      default = cfg.rules != [];
      description = "Install the rules as a zsh chpwd hook. On by default when rules are set.";
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

    runner = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = pkgs.writeShellScriptBin "directory-env" ''
        ${ruleBlocks}
        exec "$@"
      '';
      defaultText = lib.literalMD "a `directory-env` runner carrying `rules`";
      description = ''
        `directory-env CMD [ARGS...]` applies the rules matching $PWD, then
        execs CMD. For processes spawned without a shell, which never reach the
        chpwd hook — a GUI's child, a systemd unit, an agent CLI.
      '';
    };

    wrap = lib.mkOption {
      type = lib.types.functionTo lib.types.package;
      readOnly = true;
      default = exe:
        pkgs.writeShellScriptBin (baseNameOf exe) ''
          exec ${lib.getExe cfg.runner} ${exe} "$@"
        '';
      defaultText = lib.literalMD "wraps an executable in `runner`";
      description = ''
        `wrap "/nix/store/…/bin/foo"` is a package whose `foo` applies the
        rules and execs the real one — for a caller that resolves the program
        by path or off PATH rather than running it from a shell.
      '';
    };
  };

  # One chpwd handler runs every rule; registered once, fired once on init.
  config = lib.mkIf (cfg.enableZshIntegration && cfg.rules != []) {
    programs.zsh.initContent = lib.mkAfter ''
      _directory_env() {
      ${ruleBlocks}
      }
      typeset -ag chpwd_functions
      (( ''${chpwd_functions[(I)_directory_env]} )) || chpwd_functions=(_directory_env $chpwd_functions)
      _directory_env
    '';
  };
}
