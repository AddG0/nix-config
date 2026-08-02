# Define greetd options globally for consistent availability, regardless of greetd configuration import
{
  config,
  lib,
  ...
}: {
  options.services.greetd = let
    cfg = config.services.greetd;
    installed = builtins.attrNames cfg.desktops;
  in {
    # Keyed so several installed desktops register side by side instead of
    # conflicting over one value.
    desktops = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {hyprland = "uwsm start hyprland-uwsm.desktop";};
      description = "Launch command per installed desktop, keyed by name. Set by the desktop modules.";
    };

    # hyprland wherever it is installed; hosts without it fall through to theirs.
    primaryDesktop = lib.mkOption {
      type = lib.types.str;
      default =
        if cfg.desktops ? hyprland
        then "hyprland"
        else if installed == []
        then ""
        else builtins.head installed;
      description = "Which entry of desktops greetd logs into. Set it on a host whose primary is not hyprland.";
    };

    desktopCommand = lib.mkOption {
      type = lib.types.str;
      default = cfg.desktops.${cfg.primaryDesktop} or "start-hyprland";
      description = "Command that starts the desktop compositor";
    };

    # Separate so a session wrapper can read desktopCommand and set this without cycling.
    sessionCommand = lib.mkOption {
      type = lib.types.str;
      default = cfg.desktopCommand;
      description = "Command greetd runs for a session, desktop or otherwise";
    };

    username = lib.mkOption {
      type = lib.types.str;
      default = config.hostSpec.primaryUsername;
      description = "Username for greetd session";
    };

    autoLogin = {
      enable = lib.mkEnableOption "Enable automatic login";
      username = lib.mkOption {
        type = lib.types.str;
        default = config.services.greetd.username;
        description = "User to automatically login";
      };
    };
  };
}
