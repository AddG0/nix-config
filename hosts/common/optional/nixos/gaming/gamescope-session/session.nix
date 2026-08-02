# Session lifecycle: which compositor holds the VT, and how the two swap. The
# shapes and the marker protocol are described in default.nix, which owns the
# option surface and passes the shared runtime paths in.
{
  lib,
  pkgs,
  cfg,
  steamBin,
  marker,
  sessionFlag,
  displayFlagsCommand,
  desktopCmd,
}: let
  # mangoapp is an X11 client on gamescope's Xwayland, but gamescope exports
  # WAYLAND_DISPLAY to children — GLFW then inits Wayland and segfaults in
  # XInternAtom, and the reaper respawns it forever. GAMESCOPE_WAYLAND_DISPLAY stays.
  mangoappX11 = pkgs.writeShellScriptBin "mangoapp" ''
    exec ${pkgs.coreutils}/bin/env -u WAYLAND_DISPLAY ${pkgs.mangohud}/bin/mangoapp "$@"
  '';

  # gamescope spawns the --mangoapp overlay from PATH, and Steam inherits it to
  # find steamos-session-select. pkgs.gamescope is uncapped (no cap_sys_nice).
  # sessionSelect can't move to programs.steam.extraPackages: it needs steamBin,
  # and the package option's apply feeds extraPackages back in — infinite recursion.
  gamescopeWrapped = pkgs.symlinkJoin {
    name = "gamescope-session-wrapped";
    paths = [pkgs.gamescope];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = "wrapProgram $out/bin/gamescope --prefix PATH : ${lib.makeBinPath [mangoappX11 sessionSelect]}";
  };

  # On the command, not the session script: reaches both shapes, and the
  # dispatcher's desktop half never inherits it.
  envPrefix = lib.optionalString (cfg.extraEnv != {}) "${pkgs.coreutils}/bin/env ${lib.escapeShellArgs (lib.mapAttrsToList (n: v: "${n}=${v}") cfg.extraEnv)} ";

  # NOT full Deck mode: SteamDeck=1/-steamdeck route "Switch to Desktop" through
  # steamos-manager (needs jovian.steam) and hang, instead of running
  # steamos-session-select.
  gamescopeFlags = lib.concatStringsSep " " (
    ["--steam" "--rt" "--expose-wayland" "--force-grab-cursor" "--mangoapp"]
    ++ map lib.escapeShellArg cfg.extraArgs
  );
  # Pins the journal tag, which journald would otherwise derive from comm
  # (.gamescope-wrapped) — `journalctl -t gamescope`.
  gamescopeCmd = "${pkgs.systemd}/bin/systemd-cat -t gamescope ${envPrefix}${gamescopeWrapped}/bin/gamescope $gs_output ${gamescopeFlags} -- ${steamBin} -gamepadui -pipewire-dmabuf";

  # -O is start-only, so a switch means a restart — hence the read per loop.
  # Unquoted above: an empty value must vanish, and no flag here has spaces.
  readDisplay = ''gs_output="$(${displayFlagsCommand})"'';

  # The flag tells gamescope-set-display this is the session's gamescope, not a
  # per-game nested one on the desktop.
  runGamescope = "touch ${sessionFlag}; ${gamescopeCmd} || true; rm -f ${sessionFlag}";

  # Session stdout already reaches the journal on greetd's stream; this only
  # collects it under one tag: `journalctl -t gaming-session`.
  toJournal = "exec > >(${pkgs.systemd}/bin/systemd-cat -t gaming-session) 2>&1";

  # The VT keeps its text across a mode change, so it resurfaces between
  # sessions. ?25l as well: on a panel gamescope isn't driving, the bare VT
  # shows through and fbcon's blinking cursor reads as a line in the corner.
  clearVT = ''printf '\033[H\033[2J\033[3J\033[?25l' >/dev/tty 2>/dev/null || true'';

  # Back on for whatever holds the VT next — tuigreet needs a caret to type at.
  restoreVT = ''printf '\033[?25h' >/dev/tty 2>/dev/null || true'';

  # Nothing to fall back to, so quitting Steam relaunches. The backoff keeps a
  # Steam that dies at startup from spinning; Ctrl+Alt+F2 still reaches a TTY.
  # A `desktop` marker means "Switch to Desktop" was pressed: end the session for
  # the greeter instead, the only way off this host's gamescope short of a TTY.
  # A `gamescope` marker is an output switch — round again, skipping the backoff.
  # On PATH, not a store path: the greeter puts the session command on screen.
  standaloneSession = pkgs.writeShellScriptBin "gamescope-session" ''
    ${toJournal}
    while :; do
      rm -f ${marker}
      ${readDisplay}
      ${clearVT}
      start=$SECONDS
      ${runGamescope}
      [ "$(cat ${marker} 2>/dev/null || true)" = gamescope ] && continue
      [ -e ${marker} ] && break
      ((SECONDS - start < 5)) && sleep 5
    done
    ${restoreVT}
  '';

  # On PATH for the same reason as standaloneSession.
  dispatcher = pkgs.writeShellScriptBin "session-dispatcher" ''
    set -u
    ${toJournal}
    current="''${1:-desktop}"
    while :; do
      rm -f ${marker}
      ${clearVT}
      case "$current" in
        # Kept in this branch: reading connector status probes DRM, waking a
        # runtime-suspended dGPU that the desktop half should leave asleep.
        gamescope)
          ${readDisplay}
          ${runGamescope}
          ;;
        *) ${desktopCmd} || true ;;
      esac
      case "$(cat ${marker} 2>/dev/null || true)" in
        gamescope) current=gamescope ;;
        desktop) current=desktop ;;
        *) break ;;
      esac
    done
    ${restoreVT}
  '';

  # Steam's "Switch to Desktop" runs this by bare name through sh, not by path.
  sessionSelect = pkgs.writeShellScriptBin "steamos-session-select" ''
    echo desktop > ${marker}
    exec ${steamBin} -shutdown
  '';

  # App-launcher counterpart to Steam's "Switch to Desktop": `uwsm stop` ends the
  # desktop (paired with the `uwsm start` in desktopCommand) so the dispatcher
  # loops into gamescope.
  enterGaming = pkgs.writeShellScript "enter-gaming-mode" ''
    echo gamescope > ${marker}
    exec ${lib.getExe pkgs.uwsm} stop
  '';
  enterGamingApp = pkgs.makeDesktopItem {
    name = "gaming-mode";
    desktopName = "Gaming Mode";
    comment = "Switch to the Steam gamescope session";
    icon = "steam";
    exec = "${enterGaming}";
    categories = ["Game"];
  };

  gamingSession =
    (pkgs.writeTextDir "share/wayland-sessions/gaming-mode.desktop" ''
      [Desktop Entry]
      Name=Gaming Mode
      Exec=${lib.getExe dispatcher} gamescope
      Type=Application
    '')
    .overrideAttrs (_: {passthru.providedSessions = ["gaming-mode"];});
in {
  inherit dispatcher standaloneSession sessionSelect enterGamingApp gamingSession;
}
