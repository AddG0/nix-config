# Session entries and the by-name launcher, as plain functions so tests render them without a NixOS evaluation.
{
  lib,
  pkgs,
}: {
  # wrapper: null, or a command each desktop's command is appended to.
  entry = wrapper: session:
    (pkgs.writeTextDir "share/wayland-sessions/${session.sessionName}.desktop" (''
        [Desktop Entry]
        Name=${session.displayName}
        Exec=${lib.optionalString (session.desktop && wrapper != null) "${wrapper} "}${session.command}
        Type=Application
      ''
      + lib.optionalString (session.desktopNames != []) ''
        DesktopNames=${lib.concatStringsSep ";" session.desktopNames}
      ''
      + lib.optionalString session.noDisplay ''
        NoDisplay=true
      ''))
    .overrideAttrs (_: {passthru.providedSessions = [session.sessionName];});

  # Which desktops a host has and where an unpicked session lands. primaryDesktop is primarySession when that is a
  # desktop, else the first one: standalone Gaming Mode makes primarySession gaming-mode, which is not.
  plan = {
    sessions,
    primarySession,
  }: let
    desktops = lib.filterAttrs (_: session: session.desktop) sessions;
    desktopKeys = lib.attrNames desktops;
    primaryIsDesktop = primarySession != null && desktops ? ${primarySession};
  in rec {
    inherit desktops desktopKeys;
    hasLauncher = lib.length desktopKeys > 1;
    primaryDesktop =
      if primaryIsDesktop
      then primarySession
      else if desktopKeys != []
      then lib.head desktopKeys
      else null;
    loginSession =
      if hasLauncher && primaryIsDesktop
      then "desktop"
      else primarySession;
  };

  # The "Desktop" session: starts the user's default desktop (desktops.defaultSession's file), else `fallback`.
  launcher = {
    desktops,
    fallback,
  }:
    pkgs.writeShellApplication {
      name = "desktop-launcher";
      text = let
        arm = key: session: ''
          ${lib.escapeShellArg key})
            ${lib.optionalString (session.desktopNames != []) "export XDG_CURRENT_DESKTOP=${lib.escapeShellArg (lib.concatStringsSep ":" session.desktopNames)}"}
            export XDG_SESSION_DESKTOP=${lib.escapeShellArg session.sessionName}
            exec ${session.command}
            ;;
        '';
        keys = lib.concatStringsSep ", " (lib.attrNames desktops);
      in ''
        file="''${XDG_CONFIG_HOME:-$HOME/.config}/desktops/default-session"
        key=""
        if [[ -r $file ]]; then
          key=$(${pkgs.coreutils}/bin/head -n1 -- "$file" | ${pkgs.coreutils}/bin/tr -d '[:space:]')
        fi
        start() {
          case "$1" in
          ${lib.concatStrings (lib.mapAttrsToList arm desktops)}
          esac
        }
        if [[ -z $key ]]; then
          echo "desktop-launcher: no default session in $file; starting ${fallback}" >&2
        else
          start "$key"
          echo "desktop-launcher: $file names '$key', not a desktop here (${keys}); starting ${fallback}" >&2
        fi
        start ${lib.escapeShellArg fallback}
        echo "desktop-launcher: fallback '${fallback}' is not a desktop here either (${keys})" >&2
        exit 1
      '';
    };

  # greetd takes a command, not a session name, so this runs a session's Exec= as a display manager would.
  startSession = sessionsDir:
    pkgs.writeShellApplication {
      name = "start-session";
      runtimeInputs = [pkgs.gnused];
      text = ''
        session=''${1:?usage: start-session SESSION}
        entry="${sessionsDir}/$session.desktop"
        if [[ ! -f $entry ]]; then
          echo "start-session: no session '$session' in ${sessionsDir}" >&2
          exit 1
        fi
        exec_line=$(sed -n '/^Exec=/{s///p;q}' "$entry")
        if [[ -z $exec_line ]]; then
          echo "start-session: $entry has no Exec= line" >&2
          exit 1
        fi
        eval "exec $exec_line"
      '';
    };
}
