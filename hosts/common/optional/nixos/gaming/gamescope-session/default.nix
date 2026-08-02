# Steam Big Picture inside gamescope ("Gaming Mode"), in one of two shapes:
#
#   standalone — the host's only session: autologin straight into gamescope,
#                relaunched on exit. "Switch to Desktop" drops to the greeter.
#
#   otherwise  — greetd-native desktop <-> gamescope switching (SteamOS's SDDM
#                swap has no greetd backend). A dispatcher runs one session at a
#                time; a marker file picks the next after the current exits
#                (none -> greeter). Desktop half is
#                services.greetd.desktopCommand, not a hardcoded compositor.
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
    # Not a hardcoded compositor: whatever the host set as its desktop.
    desktopCmd = config.services.greetd.desktopCommand;
  };
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
  config = lib.mkIf config.services.greetd.enable (lib.mkMerge [
    {
      systemd.tmpfiles.rules = [
        "L+ /usr/bin/steamos-session-select - - - - ${lib.getExe session.sessionSelect}"
      ];
    }

    (lib.mkIf cfg.standalone {
      environment.systemPackages = [session.standaloneSession];
      services.greetd = {
        autoLogin.enable = lib.mkDefault true;
        sessionCommand = "gamescope-session";
      };
    })
    (lib.mkIf (!cfg.standalone) {
      services.displayManager.sessionPackages = [session.gamingSession];
      environment.systemPackages = [session.enterGamingApp session.dispatcher];

      # Covers both greetd slots at once — autologin's initial_session and the
      # greeter's --cmd both derive from sessionCommand.
      services.greetd.sessionCommand = "session-dispatcher desktop";
    })
  ]);
}
