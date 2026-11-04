# Fullscreens Safe Eyes breaks that Hyprland maps tiled because a Noctalia panel holds focus.
{
  config,
  lib,
  pkgs,
  ...
}: let
  fullscreenBreaks = pkgs.writeShellApplication {
    name = "safeeyes-hyprland-break-fullscreen";
    runtimeInputs = [config.wayland.windowManager.hyprland.package pkgs.gnugrep pkgs.socat];
    text = ''
      socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

      # openwindow>>ADDRESS,WORKSPACE,CLASS,TITLE; break windows are titled SafeEyes-<monitor>.
      while IFS= read -r event; do
        case "$event" in
          "openwindow>>"*",io.github.slgobinath.SafeEyes,SafeEyes-"*)
            window="''${event#openwindow>>}"
            window="0x''${window%%,*}"
            # --batch exits 0 even when a dispatch fails, so check each reply line.
            status=0
            reply=$(hyprctl --batch "dispatch focuswindow address:$window; dispatch fullscreen 0 set" 2>&1) || status=$?
            if [ "$status" -ne 0 ] || grep -qvE '^(ok)?$' <<<"$reply"; then
              echo "failed to fullscreen Safe Eyes window $window (hyprctl exit $status): $(tr '\n' ' ' <<<"$reply")" >&2
            fi
            ;;
        esac
      done < <(socat -u UNIX-CONNECT:"$socket" -)

      echo "Hyprland event socket $socket closed" >&2
      exit 1
    '';
  };
in
  lib.mkIf config.wayland.windowManager.hyprland.enable {
    systemd.user.services.safeeyes-hyprland-break-fullscreen = lib.mkMerge [
      config.lib.hyprland.startWithHyprland
      {
        Unit = {
          Description = "Fullscreen Safe Eyes break windows that Hyprland mapped without focus";
          # HYPRLAND_INSTANCE_SIGNATURE reaches the user manager only once the session is up.
          After = ["graphical-session.target"];
        };
        Service = {
          ExecStart = lib.getExe fullscreenBreaks;
          Restart = "on-failure";
          RestartSec = 5;
        };
      }
    ];
  }
