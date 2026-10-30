# Steam Big Picture inside gamescope ("Gaming Mode"), in one of two shapes:
#
#   standalone — the host's only session: autologin straight into gamescope,
#                relaunched on exit. "Switch to Desktop" drops to the greeter.
#
#   otherwise  — desktop <-> gamescope switching under any display manager
#                (ADR 0010). Every desktop session runs through a dispatcher
#                that runs one half at a time; a marker file picks the next
#                after the current exits (none -> greeter). The desktop half is
#                whichever desktop the session started.
#                  desktop->gaming: "Gaming Mode" app launcher writes `gamescope`, stops the desktop
#                  gaming->desktop: Steam "Switch to Desktop" -> steamos-session-select
#                  gaming->greeter: quit Steam, no marker
#
# session.nix and display.nix are plain functions, not modules: the two halves
# are one feature, and passing their pieces as arguments beats handing them back
# and forth through read-only options.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming.gamescopeSession;
  steamBin = "${config.programs.steam.package}/bin/steam";

  # The handshake between the halves: the display tool writes both, the session
  # loop reads them. Defined here so only one file spells the paths.
  marker = ''"''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gaming-session-next"'';
  sessionFlag = ''"''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gamescope-session-active"'';

  display = import ./display.nix {
    inherit pkgs steamBin marker sessionFlag;
  };

  session = import ./session.nix {
    inherit lib pkgs cfg steamBin marker sessionFlag;
    displayFlagsCommand = lib.getExe display.displayFlags;
    watchDisplayCommand = lib.getExe display.watchDisplay;
    desktopSessions = config.desktops.sessions;
  };

  inherit (config.desktops) primarySession;
  gamingSessionKey = "gaming-mode";
in {
  options.gaming.gamescopeSession = {
    standalone = lib.mkEnableOption "gamescope as the host's only session — autologin straight into it, no desktop to switch to";

    extraEnv = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = {};
      example = {VK_LOADER_DRIVERS_SELECT = "*nvidia*";};
      description = "Environment for the gamescope session, so per-host GPU picks stay out of the global env.";
    };

    extraArgs = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["--disable-layers"];
      description = "Extra gamescope flags for this host.";
    };

    # Read-only so the Decky plugin can reach it without duplicating steamBin.
    displayTool = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = display.setDisplay;
      description = "Helper that records which monitor and mode gamescope should start on, then restarts the session.";
    };
  };

  # Both shapes go through mkIf, never a bare `if` on cfg.standalone — reading
  # config to pick the shape of config is infinite recursion.
  config = lib.mkMerge [
    {
      systemd.tmpfiles.rules = [
        "L+ /usr/bin/steamos-session-select - - - - ${lib.getExe session.sessionSelect}"
      ];
    }

    (lib.mkIf cfg.standalone {
      desktops = {
        sessions.${gamingSessionKey} = {
          displayName = "Gaming Mode";
          command = lib.getExe session.standaloneSession;
          desktop = false;
        };
        # The default prefers any desktop, which would take autologin away from gamescope.
        primarySession = lib.mkDefault gamingSessionKey;
      };
      services.displayManager.autoLogin.enable = true;
    })
    (lib.mkIf (!cfg.standalone) {
      assertions = [
        {
          assertion = primarySession != null && primarySession != gamingSessionKey;
          message = "gaming.gamescopeSession: Switch to Desktop needs a desktop session, but desktops.primarySession is ${builtins.toJSON primarySession}. Import a desktop, or set standalone = true.";
        }
      ];

      desktops = {
        sessionWrapper = "${lib.getExe session.dispatcher} desktop";
        sessions.${gamingSessionKey} = {
          displayName = "Gaming Mode";
          command = "${lib.getExe session.dispatcher} gamescope ${lib.optionalString (primarySession != null) config.desktops.sessions.${primarySession}.command}";
          desktop = false;
        };
      };
      environment.systemPackages = [session.enterGamingApp];
    })
  ];
}
