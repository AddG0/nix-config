# Sessions by desktop, rendered as session entries for whichever display manager runs. Why: ADR 0010.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.desktops;
  render = import ./_render.nix {inherit lib pkgs;};
  plan = render.plan {inherit (cfg) sessions primarySession;};
  inherit (plan) desktops desktopKeys hasLauncher primaryDesktop;

  # Rendered beside desktops.sessions rather than in it: whether it exists depends on the sessions there.
  launcherKey = "desktop";
  launcher = render.launcher {
    inherit desktops;
    fallback = primaryDesktop;
  };
  launcherEntry = render.entry cfg.sessionWrapper {
    sessionName = launcherKey;
    displayName = "Desktop";
    desktopNames = [];
    command = lib.getExe launcher;
    noDisplay = false;
    desktop = true;
  };

  homeDefaults = lib.filterAttrs (_: key: key != null) (lib.mapAttrs (_: home: home.desktops.defaultSession or null) (config.home-manager.users or {}));
in {
  options.desktops = {
    sessions = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule ({
        name,
        config,
        ...
      }: {
        options = {
          sessionName = lib.mkOption {
            type = lib.types.str;
            default = name;
            description = "Session file name, without .desktop; an upstream entry of this name is replaced.";
          };
          displayName = lib.mkOption {
            type = lib.types.str;
            description = "Name the greeter shows.";
          };
          desktopNames = lib.mkOption {
            type = lib.types.listOf lib.types.str;
            default = [];
            description = "DesktopNames=, which SDDM and GDM export as XDG_CURRENT_DESKTOP; greetd's start-session does not.";
          };
          command = lib.mkOption {
            type = lib.types.str;
            description = "Command that starts the session.";
          };
          stop = lib.mkOption {
            type = lib.types.nullOr lib.types.str;
            default = null;
            description = "Command run inside the desktop to end it cleanly; found through its desktopNames in XDG_CURRENT_DESKTOP.";
          };
          noDisplay = lib.mkOption {
            type = lib.types.bool;
            default = false;
            description = "Leave the session out of greeters' lists while tools such as uwsm can still start it by name. Rendered as NoDisplay=, never Hidden=, which uwsm refuses.";
          };
          desktop = lib.mkOption {
            type = lib.types.bool;
            # Nobody picks a hidden session, and wrapping one that a desktop starts would nest the wrapper.
            default = !config.noDisplay;
            description = "Whether this is a desktop: sessionWrapper runs it, and primarySession falls back to it. Defaults to false for a noDisplay session.";
          };
        };
      }));
      default = {};
      example = {
        niri = {
          displayName = "Niri";
          command = "niri-session";
        };
      };
      description = "Sessions by desktop, set by the desktop modules.";
    };

    preferredSessions = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [];
      example = ["hyprland" "niri"];
      description = "Keys of desktops.sessions in order of preference; primarySession takes the first one registered.";
    };

    primarySession = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = let
        preferred = lib.filter (key: cfg.sessions ? ${key}) cfg.preferredSessions;
      in
        if preferred != []
        then lib.head preferred
        else if desktopKeys != []
        then lib.head desktopKeys
        else if cfg.sessions != {}
        then lib.head (lib.attrNames cfg.sessions)
        else null;
      description = "Key of the host's main session, which Gaming Mode's Switch to Desktop returns to: the first of preferredSessions registered, else the first desktop.";
    };

    loginSession = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = plan.loginSession;
      defaultText = lib.literalExpression ''"desktop" with several desktops and a desktop as primarySession, else config.desktops.primarySession'';
      example = "gaming-mode";
      description = "Key of the session the display manager starts by default, autologin included; \"desktop\" is the launcher into each user's desktops.defaultSession.";
    };

    defaultDesktopCommand = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      readOnly = true;
      default =
        if hasLauncher
        then lib.getExe launcher
        else if primaryDesktop != null
        then desktops.${primaryDesktop}.command
        else null;
      description = "Command that starts the logged-in user's desktop: the launcher with several desktops, else the primary one.";
    };

    sessionWrapper = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Command each desktop session's command is appended to, so the desktop runs as its child.";
    };

    startSession = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = render.startSession "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions";
      description = "Runs a session by name, for display managers that take a command rather than a session.";
    };
  };

  config = {
    assertions =
      lib.mapAttrsToList (key: session: {
        assertion = session.stop == null || session.desktopNames != [];
        message = "desktops.sessions.${key}: stop is matched through desktopNames, which is empty, so it would never run.";
      })
      cfg.sessions
      ++ [
        {
          assertion = !(hasLauncher && cfg.sessions ? ${launcherKey});
          message = "desktops.sessions.${launcherKey}: the key is taken by the launcher into each user's default desktop.";
        }
      ]
      ++ lib.mapAttrsToList (user: key: {
        assertion = desktops ? ${key};
        message = "home-manager.users.${user}.desktops.defaultSession is \"${key}\", but this host's desktops are: ${lib.concatStringsSep ", " desktopKeys}.";
      })
      homeDefaults;

    services.displayManager = {
      # The session list keeps the first entry of a name, so ours, placed first, replace upstream's.
      sessionPackages =
        lib.mkBefore (map (render.entry cfg.sessionWrapper) (lib.attrValues cfg.sessions)
          ++ lib.optional hasLauncher launcherEntry);
      # Plain priority: plasma6 and niri each mkDefault their own; loginSession is where a host picks.
      defaultSession = lib.mkIf (cfg.loginSession != null) (
        if hasLauncher && cfg.loginSession == launcherKey
        then launcherKey
        else cfg.sessions.${cfg.loginSession}.sessionName
      );
    };
  };
}
