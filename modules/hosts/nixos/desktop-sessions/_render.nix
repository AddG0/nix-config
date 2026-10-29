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
