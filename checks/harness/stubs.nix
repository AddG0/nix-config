# Stand-ins for what a module under test reads from Home Manager and from the tools it writes into.
{pkgs}: {
  # Only the Home Manager options the modules under test read.
  home = {lib, ...}: {
    options = {
      home = {
        preferXdgDirectories = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        homeDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/home/t";
        };
        profileDirectory = lib.mkOption {
          type = lib.types.str;
          default = "/home/t/.nix-profile";
        };
        file = lib.mkOption {
          type = lib.types.attrsOf lib.types.attrs;
          default = {};
        };
        packages = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [];
        };
        checks = lib.mkOption {
          type = lib.types.listOf lib.types.package;
          default = [];
        };
        username = lib.mkOption {
          type = lib.types.str;
          default = "t";
        };
      };
      xdg = {
        configHome = lib.mkOption {
          type = lib.types.str;
          default = "/home/t/.config";
        };
        configFile = lib.mkOption {
          type = lib.types.attrsOf lib.types.attrs;
          default = {};
        };
      };
      programs.git.package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.git;
      };
      warnings = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
      };
      assertions = lib.mkOption {
        type = lib.types.listOf lib.types.attrs;
        default = [];
      };
    };
  };

  # The tool modules code-assistant-profiles writes into, so a target is tested without its tool module.
  tools = {lib, ...}: {
    options = {
      programs = {
        # Typed `enable` so the target's mkDefault gates home.file; lazy so one attribute read forces no other, like Home Manager's options.
        codex = lib.mkOption {
          type = lib.types.submodule {
            freeformType = lib.types.lazyAttrsOf lib.types.anything;
            options = {
              enable = lib.mkOption {
                type = lib.types.bool;
                default = false;
              };
              # Upstream's nullable type; null by default so a deepSeq over programs.codex holds no derivation.
              package = lib.mkOption {
                type = lib.types.nullOr lib.types.package;
                default = null;
              };
            };
          };
          default = {};
        };
        opencode = lib.mkOption {
          type = lib.types.attrs;
          default = {};
        };
        claude-code-profiles = lib.mkOption {
          type = lib.types.attrsOf lib.types.anything;
          default = {};
        };
      };
    };
  };

  # A claude that prints its arguments, one per line.
  claude = pkgs.writeShellScriptBin "claude" ''
    if (( $# )); then
      printf '%s\n' "$@"
    fi
  '';
}
