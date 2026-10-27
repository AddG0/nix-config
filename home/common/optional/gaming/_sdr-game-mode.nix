# SDR game mode's daemon and its session toggle; `hyprland` supplies hyprctl, so tests can pass a fake.
{
  lib,
  pkgs,
  hyprland,
  hdrMonitors,
}: let
  hyprLib = import ../desktops/hyprland/_common/lib.nix {inherit lib;};

  # Session-wide opt-out, like Windows' Win+Alt+B; the per-game one is the keep-hdr window tag.
  pauseFlag = "$XDG_RUNTIME_DIR/sdr-game-mode.paused";
in {
  # SDR buffers only scan out on an SDR output; XWayland windows can't carry HDR, so an XWayland game is SDR,
  # as is a gamescope started without --hdr-enabled.
  switch = pkgs.writeShellApplication {
    name = "sdr-game-mode";
    runtimeInputs = [hyprland pkgs.jq pkgs.socat];
    text = ''
      hypr="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE"
      declare -A sdr_rule=(
        ${lib.concatMapStringsSep "\n  " (m: "[${m.output}]=\"${hyprLib.sdrMonitorRule m}\"") hdrMonitors}
      )

      # hyprctl exits 0 when Hyprland rejects a command, so the reply is the only signal.
      hyprctl_accepted() {
        local reply
        reply=$(hyprctl "$@" 2>&1) || true
        if [ "$reply" != ok ]; then
          echo "sdr-game-mode: hyprctl $* was rejected: $reply" >&2
          return 1
        fi
      }

      # Monitor name → addresses of the games holding it in SDR.
      held='{}'

      reconcile() {
        local monitors clients workspaces sdr_gamescope pid cmdline paused state mon wants_sdr cm holding specials special other restore=0
        if ! monitors=$(hyprctl -j monitors) || ! clients=$(hyprctl -j clients) || ! workspaces=$(hyprctl -j workspaces); then
          echo "sdr-game-mode: could not query Hyprland at $hypr — leaving monitors as they are" >&2
          return 0
        fi
        if ! sdr_gamescope=$(jq -r '.[] | select(.class == "gamescope") | .pid' <<<"$clients" | while read -r pid; do
          if cmdline=$(tr '\0' '\n' < "/proc/$pid/cmdline") && ! grep -qx -- --hdr-enabled <<<"$cmdline"; then echo "$pid"; fi
        done | jq -sc .); then
          echo "sdr-game-mode: could not check gamescope windows for HDR — treating them as HDR" >&2
          sdr_gamescope='[]'
        fi
        # fullscreen 2 is real fullscreen; 1 is maximize.
        paused=false
        if [ -e "${pauseFlag}" ]; then paused=true; fi
        # Games hold SDR until they close: a notification taking focus un-fullscreens them.
        if ! state=$(jq -rn --argjson m "$monitors" --argjson c "$clients" --argjson paused "$paused" --argjson held "$held" --argjson sdr_gamescope "$sdr_gamescope" '
          $m[] | . as $mon
          | [$c[] | select(.monitor == $mon.id and (.xwayland or (.pid | IN($sdr_gamescope[])))
                           and (.tags | any(rtrimstr("*") == "game"))
                           and (.tags | any(rtrimstr("*") == "keep-hdr") | not))] as $games
          | [$games[] | select(.fullscreen == 2 and .workspace.id == $mon.activeWorkspace.id) | .address] as $fullscreen
          | [$games[] | .address | select(. as $a | ($held[$mon.name] // []) | index($a))] as $still_held
          | (if $paused then [] else $still_held + $fullscreen | unique end) as $holding
          | "\(.name) \($holding | length > 0) \(.colorManagementPreset) \($holding | join(","))"'); then
          echo "sdr-game-mode: could not parse Hyprland's monitor/client lists — leaving monitors as they are" >&2
          return 0
        fi

        while read -r mon wants_sdr cm holding; do
          [ -n "''${sdr_rule[$mon]:-}" ] || continue
          if ! held=$(jq -c --arg mon "$mon" --arg holding "$holding" '.[$mon] = ($holding | split(",") | map(select(. != "")))' <<<"$held"); then
            echo "sdr-game-mode: could not record which games hold $mon in SDR — forgetting them" >&2
            held='{}'
          fi
          if [ "$wants_sdr" = true ] && [ "$cm" != srgb ]; then
            # A special workspace homed on this monitor blocks direct scanout even while hidden.
            if specials=$(jq -r --arg mon "$mon" '.[] | select(.id < 0 and .monitor == $mon) | .name' <<<"$workspaces") \
              && other=$(jq -r --arg mon "$mon" '[.[] | select(.name != $mon and (.disabled | not))][0].name // empty' <<<"$monitors"); then
              for special in $specials; do
                if [ -n "$other" ]; then
                  hyprctl_accepted dispatch moveworkspacetomonitor "$special" "$other" || true
                fi
              done
            else
              echo "sdr-game-mode: could not list special workspaces on $mon — direct scanout may stay blocked" >&2
            fi
            if hyprctl_accepted keyword monitor "''${sdr_rule[$mon]}"; then
              echo "sdr-game-mode: SDR game on $mon — switched it to sRGB"
            fi
          elif [ "$wants_sdr" = false ] && [ "$cm" = srgb ]; then
            restore=1
          fi
        done <<<"$state"

        if [ "$restore" = 1 ] && hyprctl_accepted reload; then
          echo "sdr-game-mode: no SDR game left — reloaded to restore HDR"
        fi
      }

      restore_on_exit() {
        local forced
        if ! forced=$(hyprctl -j monitors | jq -r '.[] | select(.colorManagementPreset == "srgb") | .name'); then
          echo "sdr-game-mode: could not query Hyprland on exit — a monitor may be left in sRGB; run hyprctl reload" >&2
          return 0
        fi
        for mon in $forced; do
          if [ -n "''${sdr_rule[$mon]:-}" ]; then
            if hyprctl_accepted reload; then
              echo "sdr-game-mode: stopped with $mon forced to sRGB — reloaded to restore HDR"
            fi
            return 0
          fi
        done
      }
      trap restore_on_exit EXIT
      trap 'exit 0' INT TERM

      reconcile
      socat -U - UNIX-CONNECT:"$hypr/.socket2.sock" | while IFS= read -r event; do
        case $event in
          fullscreen'>>'* | workspacev2'>>'* | closewindow'>>'* | movewindowv2'>>'* | monitoradded'>>'* | custom'>>'sdr-game-mode)
            # Drain the burst one action produces, then reconcile once on the settled state.
            while IFS= read -r -t 0.2 _; do :; done
            reconcile
            ;;
        esac
      done
    '';
  };

  toggle = pkgs.writeShellApplication {
    name = "sdr-game-mode-toggle";
    runtimeInputs = [hyprland pkgs.coreutils pkgs.libnotify];
    text = ''
      if [ -e "${pauseFlag}" ]; then
        rm -f "${pauseFlag}"
        message="SDR games switch the monitor to SDR again"
      else
        touch "${pauseFlag}"
        message="SDR games stay in HDR for this session"
      fi
      if ! reply=$(hyprctl dispatch event sdr-game-mode 2>&1) || [ "$reply" != ok ]; then
        echo "sdr-game-mode-toggle: could not signal sdr-game-mode through Hyprland: $reply" >&2
        notify-send -u critical "SDR game mode" "Toggled, but sdr-game-mode was not told: $reply"
        exit 1
      fi
      # Outlasts the monitor's blank while it changes colour mode.
      notify-send -t 6000 -h string:x-canonical-private-synchronous:sdr-game-mode "SDR game mode" "$message"
    '';
  };
}
