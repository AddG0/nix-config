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
  watchDisplayCommand,
  desktopSessions,
}: let
  # Held by the dispatcher for as long as it runs, so the launcher can tell a wrapped desktop from a bare one.
  dispatcherFlag = ''"''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/session-dispatcher-active"'';
  flock = "${pkgs.util-linux}/bin/flock";

  # mangoapp is an X11 client on gamescope's Xwayland, but gamescope exports
  # WAYLAND_DISPLAY to children — GLFW then inits Wayland and segfaults in
  # XInternAtom, and the reaper respawns it forever. GAMESCOPE_WAYLAND_DISPLAY stays.
  mangoappX11 = pkgs.writeShellScriptBin "mangoapp" ''
    # FLAKE-UPDATE: drop once gamescope's fwrite uses strlen, not sizeof — the NUL
    # terminator lands in the config and mangohud rejects the key, so the overlay
    # never starts hidden for Steam to switch on. Re-check after `nix flake update`:
    # https://github.com/ValveSoftware/gamescope/blob/3.16.24/src/main.cpp#L671-L672
    if [ -s "''${MANGOHUD_CONFIGFILE:-}" ]; then
      ${pkgs.coreutils}/bin/tr -d '\0' <"$MANGOHUD_CONFIGFILE" \
        >"$MANGOHUD_CONFIGFILE.clean" &&
        ${pkgs.coreutils}/bin/mv "$MANGOHUD_CONFIGFILE.clean" "$MANGOHUD_CONFIGFILE"
    fi
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

  gamescopeFlags = lib.concatStringsSep " " (
    ["--steam" "--rt" "--expose-wayland" "--force-grab-cursor" "--mangoapp"]
    ++ map lib.escapeShellArg cfg.extraArgs
  );
  # Pins the journal tag, which journald would otherwise derive from comm
  # (.gamescope-wrapped) — `journalctl -t gamescope`.
  # Deck mode registers SteamClient.System.Perf, which gates the Quick Access
  # Menu's Performance Overlay toggle; -steamos3 is paired per ChimeraOS, unverified.
  gamescopeCmd = "${pkgs.systemd}/bin/systemd-cat -t gamescope ${envPrefix}${gamescopeWrapped}/bin/gamescope $gs_output ${gamescopeFlags} -- ${steamBin} -gamepadui -steamdeck -steamos3 -pipewire-dmabuf";

  # -O is start-only, so a switch means a restart — hence the read per loop.
  # Unquoted above: an empty value must vanish, and no flag here has spaces.
  readDisplay = ''gs_output="$(${displayFlagsCommand})"'';

  # The flag tells gamescope-set-display this is the session's gamescope, not a
  # per-game nested one on the desktop. Held as a lock, not just created: the
  # kernel drops it however this dies, so a SIGKILL cannot leave the tool
  # believing a session it can restart is still up.
  runGamescope = ''
    exec 9>${sessionFlag}
    ${pkgs.util-linux}/bin/flock -n 9 || true
    ${watchDisplayCommand} &
    watcher=$!
    ${gamescopeCmd} || true
    kill "$watcher" 2>/dev/null || true
    exec 9>&-
    rm -f ${sessionFlag}
  '';

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

  # The rest of the arguments start the desktop the session returns to.
  dispatcher = pkgs.writeShellScriptBin "session-dispatcher" ''
    set -u
    ${toJournal}
    current="''${1:?usage: session-dispatcher desktop|gamescope DESKTOP-COMMAND...}"
    shift
    if (($# == 0)); then
      echo "session-dispatcher: no desktop command after '$current'" >&2
      exit 2
    fi
    exec 8>${dispatcherFlag}
    ${flock} -n 8 || true
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
        *) "$@" || true ;;
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

  # Launcher counterpart to Steam's "Switch to Desktop": stops the current desktop so the dispatcher loops into gamescope.
  stopArms = lib.concatStrings (lib.mapAttrsToList (_: desktop:
    lib.concatMapStrings (desktopName: ''
      *:${desktopName}:*) stop() { ${desktop.stop}; } ;;
    '')
    desktop.desktopNames)
  (lib.filterAttrs (_: desktop: desktop.stop != null) desktopSessions));
  enterGaming = pkgs.writeShellScript "enter-gaming-mode" ''
    # $1 is shown to the user; $2, when given, is the journal's more technical reason.
    refuse() {
      ${pkgs.libnotify}/bin/notify-send -a "Gaming Mode" "Gaming Mode" "$1" || true
      echo "enter-gaming-mode: ''${2:-$1}" >&2
      exit 1
    }
    if ${flock} -n ${dispatcherFlag} true 2>/dev/null; then
      refuse "Gaming Mode can't switch from this session. Log out and pick your desktop from the login screen's session list." \
        "session-dispatcher is not running in this session, so nothing would start gamescope"
    fi
    case ":''${XDG_CURRENT_DESKTOP:-}:" in
    ${stopArms}
      *) refuse "No stop command for desktop ''${XDG_CURRENT_DESKTOP:-unknown}." ;;
    esac
    echo gamescope > ${marker}
    if ! stop; then
      rm -f ${marker}
      refuse "Stopping ''${XDG_CURRENT_DESKTOP} failed, so Gaming Mode did not start."
    fi
  '';
  enterGamingApp = pkgs.makeDesktopItem {
    name = "gaming-mode";
    desktopName = "Gaming Mode";
    comment = "Switch to the Steam gamescope session";
    icon = "steam";
    exec = "${enterGaming}";
    categories = ["Game"];
  };
in {
  inherit dispatcher standaloneSession sessionSelect enterGamingApp;
}
