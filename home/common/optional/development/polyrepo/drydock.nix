{
  config,
  lib,
  pkgs,
  customPkgs,
  ...
}: let
  inherit (config.polyrepo) ghqRoot;
  cfg = config.polyrepo.drydock;
  toml = pkgs.formats.toml {};
  drydock = lib.getExe customPkgs.drydock;

  absolute = map (p: "${ghqRoot}/${p}");
  # --root replaces the configured roots, and each root set gets its own cache.
  rootFlags = roots: lib.concatMapStringsSep " " (r: "--root ${lib.escapeShellArg r}") (absolute roots);
in {
  options.polyrepo.drydock.views = lib.mkOption {
    type = lib.types.attrsOf (lib.types.listOf lib.types.str);
    default = {};
    description = "Shell alias → ghq-root-relative dirs it opens drydock on. Each dir's immediate subdirs become drydock groups, so name owner-level dirs, not hosts.";
    example = {ddp = ["gitlab.com/me" "github.com"];};
  };

  options.polyrepo.drydock.ignoreBranches = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [];
    description = "Branch globs drydock never counts as unpushed or behind, for branches CI deletes and rebuilds.";
    example = ["nightly"];
  };

  config = {
    polyrepo.drydock.views.ddp = ["gitlab.com/addg09" "github.com" "scratch"];

    home.packages = [customPkgs.drydock];

    home.shellAliases = lib.mapAttrs (_: roots: "drydock ${rootFlags roots}") cfg.views;

    xdg.configFile."drydock/config.toml".source = toml.generate "drydock-config.toml" {
      roots = absolute (lib.unique (lib.concatLists (lib.attrValues cfg.views)));
      # Deepest clone today sits five levels below its view root; one spare.
      max_depth = 6;
      status.ignore_branches = cfg.ignoreBranches;
      # Watching inotifies every dir (node_modules too) and stalls startup; a sweep is <1s.
      refresh = {
        watch = false;
        interval = "1m";
      };
      # The timer below fetches; the dashboard just reads the refs it leaves.
      remote = {
        fetch = false;
        concurrency = 8;
        timeout = "30s";
      };
      ui =
        {
          # Open on repos holding my work; `behind` is left off because after a
          # fetch every dormant clone is behind, which only means "needs a pull".
          default_filters = ["dirty" "unpushed" "no-upstream" "in-progress" "conflicted" "detached"];
          default_sort = "group";
          # No release columns: nothing here is released from a local checkout.
          columns = ["group" "repo" "branch" "changes" "stashes" "ahead" "behind" "fetched" "age"];
        }
        // lib.optionalAttrs pkgs.stdenv.hostPlatform.isLinux {
          editor_command = ["ghostty" "--working-directory={path}" "-e" "nvim"];
          terminal_command = ["ghostty" "--working-directory={path}"];
          git_client_command = ["gitkraken" "--path" "{path}"];
          file_manager_command = ["xdg-open" "{path}"];
        };
    };

    systemd.user.services.drydock-fetch = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Unit.Description = "Fetch every ghq clone so drydock's behind counts are current";
      Service = {
        Type = "oneshot";
        ExecStart = "${drydock} scan --fetch";
        Nice = 10;
      };
    };

    systemd.user.timers.drydock-fetch = lib.mkIf pkgs.stdenv.hostPlatform.isLinux {
      Unit.Description = "Periodic fetch of all ghq clones";
      Timer = {
        OnStartupSec = "10m";
        OnUnitActiveSec = "2h";
      };
      Install.WantedBy = ["timers.target"];
    };
  };
}
