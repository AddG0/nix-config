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

  # Per-game mouse DPI. Stashes the pre-game DPI on the first game of a
  # session (subsequent games keep that original), sets the per-game value,
  # then exec's the game. The mouse-dpi-restore service handles cleanup
  # via GameMode's D-Bus ClientCount=0 signal.
  # Usage: `wrappers = mouseDpi 800 ++ [gamemoderun] ++ gamescope;`
  mouseDpi = dpi:
    lib.optionals razerEnabled [
      (lib.getExe (pkgs.writeShellApplication {
        name = "mouse-dpi-${toString dpi}";
        runtimeInputs = with pkgs; [glib coreutils razerMousePath];
        text = ''
          set -u
          if mouse_path=$(razer-mouse-path); then
            state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/gaming-mouse-dpi"
            prev_file="$state_dir/prev"
            mkdir -p "$state_dir"
            if [ ! -f "$prev_file" ]; then
              cur=$(gdbus call --session --dest org.razer \
                --object-path "$mouse_path" \
                --method razer.device.dpi.getDPI 2>/dev/null) || cur=""
              # ([1800, 1800],) → "1800 1800"
              if [[ "$cur" =~ ([0-9]+)[,\ ]+([0-9]+) ]]; then
                echo "''${BASH_REMATCH[1]} ''${BASH_REMATCH[2]}" > "$prev_file"
              fi
            fi
            gdbus call --session --dest org.razer \
              --object-path "$mouse_path" \
              --method razer.device.dpi.setDPI ${toString dpi} ${toString dpi} \
              >/dev/null 2>&1 || true
          fi
          exec "$@"
        '';
      }))
    ];

  mouseDpiRestoreApp = pkgs.writeShellApplication {
    name = "mouse-dpi-restore";
    runtimeInputs = with pkgs; [glib coreutils razerMousePath];
    text = ''
      set -u
      state_dir="''${XDG_STATE_HOME:-$HOME/.local/state}/gaming-mouse-dpi"
      prev_file="$state_dir/prev"

      restore_if_needed() {
        [ -f "$prev_file" ] || return 0
        local px py mouse_path
        read -r px py < "$prev_file" || return 0
        if mouse_path=$(razer-mouse-path); then
          gdbus call --session --dest org.razer \
            --object-path "$mouse_path" \
            --method razer.device.dpi.setDPI "$px" "$py" \
            >/dev/null 2>&1 || true
        fi
        rm -f "$prev_file"
      }

      no_games_running() {
        local out
        out=$(gdbus call --session \
          --dest com.feralinteractive.GameMode \
          --object-path /com/feralinteractive/GameMode \
          --method org.freedesktop.DBus.Properties.Get \
          com.feralinteractive.GameMode ClientCount 2>/dev/null) || return 1
        [[ "$out" =~ \<([0-9]+)\> ]] && [ "''${BASH_REMATCH[1]}" = "0" ]
      }

      # Reconcile at start in case games already exited before service start.
      no_games_running && restore_if_needed

      while IFS= read -r line; do
        case "$line" in
          *PropertiesChanged*ClientCount*)
            no_games_running && restore_if_needed
            ;;
        esac
      done < <(gdbus monitor --session \
        --dest com.feralinteractive.GameMode \
        --object-path /com/feralinteractive/GameMode)
    '';
  };

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
    };
in {
  imports = [
    inputs.steam-config-nix.homeModules.default
  ];

  programs.steam.config = {
    enable = true;
    closeSteam = true;
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

      # Its very buggy when not in a 16:9 aspect ratio.
      repo.launchOptions.wrappers = [gamemoderun] ++ gamescope;

      # PROTON_ENABLE_HDR=1 is needed in addition to gamescope --hdr-enabled:
      # Overwatch's Battle.net launcher tree doesn't inherit gamescope's
      # late-set DXVK_HDR=1, so the env var must be set up front.
      # Known issue: the in-game HDR toggle reverts when re-opening settings
      # (DXGI re-query returns inconsistent caps). Re-enable each session.
      overwatch = {
        launchOptions.wrappers = [gamemoderun] ++ gamescope;
        launchOptions.env.PROTON_ENABLE_HDR = "1";
      };

      aimlabs.launchOptions.wrappers = mouseDpi 1600 ++ [gamemoderun];
    };
  };

  systemd.user.services.mouse-dpi-restore = lib.mkIf razerEnabled {
    Unit = {
      Description = "Restore mouse DPI when GameMode reports no clients";
      After = ["graphical-session.target"];
      PartOf = ["graphical-session.target"];
    };
    Service = {
      Type = "simple";
      ExecStart = lib.getExe mouseDpiRestoreApp;
      # Always restart — gdbus monitor exits silently when gamemoded
      # restarts, leaving the service "active" but no longer watching.
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = ["graphical-session.target"];
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
