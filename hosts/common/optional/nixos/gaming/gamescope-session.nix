# Steam Big Picture inside gamescope ("Gaming Mode"), in one of two shapes:
#
#   standalone — the host's only session: autologin straight into gamescope,
#                relaunched on exit. "Switch to Desktop" drops to the greeter.
#
#   otherwise  — greetd-native desktop <-> gamescope switching (SteamOS's SDDM
#                swap has no greetd backend). A dispatcher runs one session at a
#                time; a marker file picks the next after the current exits
#                (none -> greeter). Desktop half is
#                services.greetd.sessionCommand, not a hardcoded compositor.
#                  desktop->gaming: "Gaming Mode" app launcher writes `gamescope`, stops the desktop
#                  gaming->desktop: Steam "Switch to Desktop" -> steamos-session-select
#                  gaming->greeter: quit Steam, no marker
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.gaming.gamescopeSession;
  steamBin = "${config.programs.steam.package}/bin/steam";

  # mangoapp is an X11 client on gamescope's Xwayland, but gamescope exports
  # WAYLAND_DISPLAY to children — GLFW then inits Wayland and segfaults in
  # XInternAtom, and the reaper respawns it forever. GAMESCOPE_WAYLAND_DISPLAY stays.
  mangoappX11 = pkgs.writeShellScriptBin "mangoapp" ''
    exec ${pkgs.coreutils}/bin/env -u WAYLAND_DISPLAY ${pkgs.mangohud}/bin/mangoapp "$@"
  '';

  # gamescope spawns the --mangoapp overlay from PATH; hand it the shim above
  # rather than the global env. pkgs.gamescope is uncapped (no cap_sys_nice).
  gamescopeWithMango = pkgs.symlinkJoin {
    name = "gamescope-mangoapp";
    paths = [pkgs.gamescope];
    nativeBuildInputs = [pkgs.makeWrapper];
    postBuild = "wrapProgram $out/bin/gamescope --prefix PATH : ${mangoappX11}/bin";
  };

  # On the command, not the session script: reaches both shapes, and the
  # dispatcher's desktop half never inherits it.
  envPrefix = lib.optionalString (cfg.extraEnv != {}) "${pkgs.coreutils}/bin/env ${lib.escapeShellArgs (lib.mapAttrsToList (n: v: "${n}=${v}") cfg.extraEnv)} ";

  # NOT full Deck mode: SteamDeck=1/-steamdeck route "Switch to Desktop" through
  # steamos-manager (needs jovian.steam) and hang, instead of exec'ing
  # /usr/bin/steamos-session-select.
  gamescopeFlags = lib.concatStringsSep " " (
    ["--steam" "--rt" "--expose-wayland" "--force-grab-cursor" "--mangoapp"]
    ++ map lib.escapeShellArg cfg.extraArgs
  );
  # Through systemd-cat, or gamescope's log lands on the session's VT where only
  # root can read it back — `journalctl -t gamescope` instead.
  gamescopeCmd = "${pkgs.systemd}/bin/systemd-cat -t gamescope ${envPrefix}${gamescopeWithMango}/bin/gamescope $gs_output ${gamescopeFlags} -- ${steamBin} -gamepadui -pipewire-dmabuf";

  marker = ''"''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gaming-session-next"'';

  # Not in XDG_RUNTIME_DIR: the pick has to outlive a reboot.
  outputState = ''"$HOME/.local/state/gamescope-output"'';

  # -O is start-only, so a switch means a restart — hence the read per loop.
  # Unquoted above: an empty value must vanish, and connector names have no spaces.
  readOutput = ''gs_output=""; [ -s ${outputState} ] && gs_output="-O $(cat ${outputState})" || true'';

  # Marks the session's gamescope so gamescope-set-output can tell it from a
  # per-game nested one on the desktop.
  sessionFlag = ''"''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/gamescope-session-active"'';
  runGamescope = "touch ${sessionFlag}; ${gamescopeCmd} || true; rm -f ${sessionFlag}";

  # Nothing to fall back to, so quitting Steam relaunches. The backoff keeps a
  # Steam that dies at startup from spinning; Ctrl+Alt+F2 still reaches a TTY.
  # A `desktop` marker means "Switch to Desktop" was pressed: end the session for
  # the greeter instead, the only way off this host's gamescope short of a TTY.
  # A `gamescope` marker is an output switch — round again, skipping the backoff.
  standaloneSession = pkgs.writeShellScript "gamescope-session" ''
    while :; do
      rm -f ${marker}
      ${readOutput}
      start=$SECONDS
      ${runGamescope}
      [ "$(cat ${marker} 2>/dev/null || true)" = gamescope ] && continue
      [ -e ${marker} ] && break
      ((SECONDS - start < 5)) && sleep 5
    done
  '';

  desktopCmd = config.services.greetd.sessionCommand;

  dispatcher = pkgs.writeShellScript "session-dispatcher" ''
    set -u
    current="''${1:-desktop}"
    while :; do
      rm -f ${marker}
      ${readOutput}
      case "$current" in
        gamescope) ${runGamescope} ;;
        *) ${desktopCmd} || true ;;
      esac
      case "$(cat ${marker} 2>/dev/null || true)" in
        gamescope) current=gamescope ;;
        desktop) current=desktop ;;
        *) break ;;
      esac
    done
  '';

  # Steam's "Switch to Desktop" execs /usr/bin/steamos-session-select.
  sessionSelect = pkgs.writeShellScriptBin "steamos-session-select" ''
    echo desktop > ${marker}
    exec ${steamBin} -shutdown
  '';

  # Takes a priority list, not one name: a pick that is unplugged later falls
  # through to the next instead of leaving gamescope with no output at all.
  setOutput = pkgs.writeShellApplication {
    name = "gamescope-set-output";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      state=${outputState}

      case "''${1:-}" in
        --get)
          cat "$state" 2>/dev/null || true
          exit 0
          ;;
        --list)
          for c in /sys/class/drm/card*-*; do
            [ "$(cat "$c/status" 2>/dev/null)" = connected ] || continue
            n=''${c##*/}
            printf '%s\n' "''${n#*-}"
          done
          exit 0
          ;;
        --clear)
          rm -f "$state"
          ;;
        "" | -*)
          echo "usage: gamescope-set-output <connector[,fallback...]> | --get | --list | --clear" >&2
          exit 2
          ;;
        *)
          mkdir -p "$(dirname "$state")"
          printf '%s\n' "$1" >"$state"
          ;;
      esac

      # Off the session, ending Steam would leave a marker that sends the next
      # desktop exit into Gaming Mode.
      if [ ! -e ${sessionFlag} ]; then
        echo "recorded; Gaming Mode is not running, so nothing to restart" >&2
        exit 0
      fi

      echo gamescope > ${marker}
      exec ${steamBin} -shutdown
    '';
  };

  # App-launcher counterpart to Steam's "Switch to Desktop": `uwsm stop` ends the
  # desktop (paired with the `uwsm start` in sessionCommand) so the dispatcher
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
      Exec=${dispatcher} gamescope
      Type=Application
    '')
    .overrideAttrs (_: {passthru.providedSessions = ["gaming-mode"];});
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
    outputTool = lib.mkOption {
      type = lib.types.package;
      readOnly = true;
      default = setOutput;
      description = "Helper that records which connector gamescope should start on, then restarts the session on it.";
    };
  };

  # Both shapes go through mkIf, never a bare `if` on cfg.standalone — reading
  # config to pick the shape of config is infinite recursion.
  config = lib.mkIf config.services.greetd.enable (lib.mkMerge [
    {
      environment.systemPackages = [setOutput];
      systemd.tmpfiles.rules = [
        "L+ /usr/bin/steamos-session-select - - - - ${lib.getExe sessionSelect}"
      ];
    }

    (lib.mkIf cfg.standalone {
      services.greetd = {
        autoLogin.enable = lib.mkDefault true;
        sessionCommand = "${standaloneSession}";
      };
    })
    (lib.mkIf (!cfg.standalone) {
      services.displayManager.sessionPackages = [gamingSession];
      environment.systemPackages = [enterGamingApp];

      # Override the command, not sessionCommand, or desktopCmd's read of it
      # cycles. mkIf must guard the whole table — a leaf-only mkIf leaves an
      # empty [initial_session] that greetd rejects.
      services.greetd.settings.initial_session = lib.mkIf config.services.greetd.autoLogin.enable {
        command = lib.mkForce "${dispatcher} desktop";
      };
    })
  ]);
}
