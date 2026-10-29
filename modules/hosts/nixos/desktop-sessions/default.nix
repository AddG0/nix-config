# Sessions by desktop, rendered as session entries for whichever display manager runs. Why: ADR 0010.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.desktops;
  render = import ./_render.nix {inherit lib pkgs;};
  desktopKeys = lib.attrNames (lib.filterAttrs (_: session: session.desktop) cfg.sessions);
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
      description = "Key of the session logged into by default: the first of preferredSessions registered, else the first desktop.";
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
      cfg.sessions;

    services.displayManager = {
      # The session list keeps the first entry of a name, so ours, placed first, replace upstream's.
      sessionPackages = lib.mkBefore (map (render.entry cfg.sessionWrapper) (lib.attrValues cfg.sessions));
      # Plain priority: plasma6 and niri each mkDefault their own; primarySession is where a host picks.
      defaultSession = lib.mkIf (cfg.primarySession != null) cfg.sessions.${cfg.primarySession}.sessionName;
    };
  };
}
