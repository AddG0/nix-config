# Steam overlay missing in games: Steam → Settings → Interface → uncheck "Use GPU accelerated rendering in web views".
{
  config,
  osConfig ? null,
  inputs,
  pkgs,
  lib,
  ...
}: let
  razerEnabled = osConfig.hardware.openrazer.enable or false;
  defaultCompatTool = "GE-Proton";
  primaryMonitor = lib.findFirst (m: m.primary) null config.display.monitors;
  gamemoderun = lib.getExe' pkgs.gamemode "gamemoderun";

  # Gamescope preconfigured for the primary monitor's native resolution.
  # Opt in per-game by spreading into wrappers:
  #   launchOptions.wrappers = [gamemoderun] ++ gamescope;
  # Skip for: anti-cheat games (EAC), games where Steam overlay must work,
  # games run via PROTON_ENABLE_WAYLAND=1, and titles you want to tile freely.
  # `env -u WAYLAND_DISPLAY` works around gamescope hanging on game exit
  # because the host compositor's WAYLAND_DISPLAY leaks into the nested
  # session and wineserver waits indefinitely on the outer socket.
  # See: github.com/ValveSoftware/gamescope/issues/1396
  # --hdr-enabled is included automatically whenever the primary monitor
  # advertises HDR — no separate SDR/HDR wrappers needed. SDR games
  # composite through the HDR pipeline transparently.
  mkGamescope = {extraArgs ? []}:
    [
      "env"
      "-u"
      "WAYLAND_DISPLAY"
      (lib.getExe pkgs.gamescope)
      "-W"
      (toString primaryMonitor.width)
      "-H"
      (toString primaryMonitor.height)
      "-w"
      (toString primaryMonitor.width)
      "-h"
      (toString primaryMonitor.height)
      "-r"
      (toString primaryMonitor.refreshRate)
      "-f"
    ]
    ++ lib.optionals (primaryMonitor.hdr or false) ["--hdr-enabled"]
    ++ extraArgs
    ++ ["--"];

  gamescope = mkGamescope {};

  # Helper: print the D-Bus object path of the first openrazer device that
  # supports DPI control, or exit nonzero if no such device is connected.
  razerMousePath = pkgs.writeShellApplication {
    name = "razer-mouse-path";
    runtimeInputs = with pkgs; [glib gnugrep coreutils];
    text = ''
      serials=$(gdbus call --session --dest org.razer \
        --object-path /org/razer \
        --method razer.devices.getDevices 2>/dev/null) || exit 1
      for s in $(echo "$serials" | grep -oE "'[^']+'" | tr -d "'"); do
        if gdbus introspect --session --dest org.razer \
            --object-path "/org/razer/device/$s" 2>/dev/null \
            | grep -q "razer.device.dpi"; then
          echo "/org/razer/device/$s"
          exit 0
        fi
      done
      exit 1
    '';
  };

  # Per-game mouse DPI. Captures the baseline, sets the per-game value, runs
  # the game, and restores the baseline when the game exits.
  #
  # Restore can't simply wait on the wrapped process: Proton games sit behind
  # a launcher/anti-cheat (Overwatch's BattlEye belauncher, Battle.net, the EA
  # app) that stays alive after the game window closes, so the wrapped process
  # only returns much later. Steam points STEAM_COMPAT_INSTALL_PATH at the
  # game's own files while the launcher lives in the wine prefix — so we watch
  # the executables shipped with the game and restore when the last one exits.
  # Native games have no such indirection, so we just wait on the process.
  # Usage: `wrappers = mouseDpi 800 ++ [gamemoderun] ++ gamescope;`
  mouseDpi = dpi:
    lib.optionals razerEnabled [
      (lib.getExe (pkgs.writeShellApplication {
        name = "mouse-dpi-${toString dpi}";
        runtimeInputs = with pkgs; [glib coreutils findutils procps razerMousePath];
        text = ''
          set -u

          # No DPI-capable Razer mouse → just run the game untouched.
          if ! mouse_path=$(razer-mouse-path); then
            exec "$@"
          fi

          prev_file="''${XDG_STATE_HOME:-$HOME/.local/state}/gaming-mouse-dpi/prev"
          mkdir -p "$(dirname "$prev_file")"

          dpi_call() {
            local method=$1
            shift
            gdbus call --session --dest org.razer \
              --object-path "$mouse_path" --method "razer.device.dpi.$method" "$@" 2>/dev/null
          }
          set_dpi() { dpi_call setDPI "$1" "$2" >/dev/null || true; }
          get_dpi() {
            # ([1800, 1800],) → "1800 1800"
            local out
            out=$(dpi_call getDPI) && [[ "$out" =~ ([0-9]+)[,\ ]+([0-9]+) ]] || return 1
            echo "''${BASH_REMATCH[1]} ''${BASH_REMATCH[2]}"
          }

          restore() {
            [ -f "$prev_file" ] || return 0
            local px py
            read -r px py < "$prev_file" && set_dpi "$px" "$py"
            rm -f "$prev_file"
          }

          # Self-heal a leftover prev_file from a prior wrapper SIGKILLed
          # before its trap ran, so we never capture a game value as baseline.
          restore
          get_dpi > "$prev_file" || rm -f "$prev_file"
          set_dpi ${toString dpi} ${toString dpi}

          if [ -z "''${STEAM_COMPAT_INSTALL_PATH:-}" ]; then
            # Native game: the wrapped process is the game itself.
            trap restore EXIT INT TERM HUP
          else
            # Proton game: a launcher/anti-cheat outlives the game, so restore
            # once the game's own executables are all gone.
            mapfile -t exes < <(find "$STEAM_COMPAT_INSTALL_PATH" \
              -maxdepth 4 -iname '*.exe' -printf '%.15f\n' 2>/dev/null)
            game_running() {
              # comm is truncated to 15 chars; exe names were too (-printf %.15f).
              local e
              for e in "''${exes[@]}"; do pgrep -x "$e" >/dev/null 2>&1 && return 0; done
              return 1
            }
            (
              until game_running; do sleep 2; done
              while game_running; do sleep 2; done
              restore
            ) &
            watcher=$!
            trap 'kill "$watcher" 2>/dev/null || true; restore' EXIT INT TERM HUP
          fi

          "$@"
        '';
      }))
    ];

  # name → Steam appid. Each game gets a default config of
  # `{ id; launchOptions.wrappers = [gamemoderun]; }`; per-game overrides
  # are merged below.
  defaults =
    lib.mapAttrs (_: id: {
      inherit id;
      launchOptions.wrappers = [gamemoderun];
    }) {
      rocket-league = 252950;
      satisfactory = 526870;
      ark-survival-ascended = 2399830;
      conan-exiles = 440900;
      repo = 3241660;
      lethal-company = 1966720;
      subnautica-2 = 1962700;
      phasmophobia = 739630;
      overwatch = 2357570;
      horizon-zero-dawn = 2561580; # Remastered. Use 1151640 for original Complete Edition.
      avatar-frontiers-of-pandora = 2840770;
      escape-simulator = 1435790;
      escape-simulator-2 = 2879840;
      forza-horizon-4 = 1293830;
      forza-horizon-5 = 1551360;
      forza-horizon-6 = 2483190;
      tmodloader = 1281930;
      terraria = 105600;
      terratech = 285920;
      subnautica = 264710;
      subnautica-below-zero = 848450;
      scrap-mechanic = 387990;
      bloons-td-6 = 960090;
      split-fiction = 2001120;
      schedule-1 = 3164500;
      marvel-rivals = 2767030;
      ultrakill = 1229490;
      trackmania = 2225070;
      it-takes-two = 1426210;
      aimlabs = 714010;
      portal-2 = 620;
      fps-chess = 2021910;

      # VR
      bigscreen-beyond-utility = 2467050;
    };
in {
  imports = [
    inputs.steam-config-nix.homeModules.default
  ];

  programs.steam.config = {
    enable = true;
    onSteamRunning = "close";
    inherit defaultCompatTool;
    apps = lib.recursiveUpdate defaults {
      # Rocket League has a linux build, but it's not maintained so we need to use the windows version
      rocket-league.compatTool = defaultCompatTool;

      # I had multiplayer issues with the linux version. So I'm using the windows version.
      portal-2.compatTool = defaultCompatTool;

      # Gamescope wrap: HZD's native fullscreen on Linux/Proton is broken
      # (wrong resolution, multi-monitor misbehavior, alt-tab loss).
      # Gamescope forces a sane fullscreen surface and fixes it.
      horizon-zero-dawn.launchOptions.wrappers = [gamemoderun] ++ gamescope;

      aimlabs.launchOptions.wrappers = mouseDpi 1600 ++ [gamemoderun];

      # Wrap in gaemscope to fix weird fullscreen behavior
      forza-horizon-4.launchOptions.wrappers = [gamemoderun] ++ gamescope;
      forza-horizon-5.launchOptions.wrappers = [gamemoderun] ++ gamescope;
      forza-horizon-6.launchOptions.wrappers = [gamemoderun] ++ gamescope;

      overwatch.launchOptions.wrappers = mouseDpi 1800 ++ [gamemoderun];

      # Bigscreen Beyond Utility — Windows-only app for adjusting the
      # headset's fan, brightness, refresh rate, and LED color.
      # Intentionally minimal: PROTON_ENABLE_HIDRAW is documented but
      # appears to make things worse on Proton 10.x / Experimental
      # (BeyondHID logs "parent not found" with it set). The first
      # successful detection at 14:06 happened with no override at all.
      # https://github.com/ValveSoftware/Proton/issues/8672
    };
  };

  # Enable multi-threaded Vulkan shader compilation for Steam
  # By default Steam uses only 1 thread, causing slow shader processing
  #
  # NOTE: You must also enable "Allow background processing of Vulkan shaders"
  # in Steam → Settings → Downloads. This setting can only be toggled via GUI,
  # not via config files (it's stored in config.vdf which Steam manages internally).
  home.file.".steam/steam/steam_dev.cfg".text = ''
    unShaderBackgroundProcessingThreads 1
  '';
}
