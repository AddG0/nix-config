{pkgs, ...}: let
  hyprshot = "${pkgs.hyprshot}/bin/hyprshot";
  wpctl = "${pkgs.wireplumber}/bin/wpctl";
  brightnessctl = "${pkgs.brightnessctl}/bin/brightnessctl";
  brightness-step = pkgs.writeShellScriptBin "hypr-brightness" ''
    set -eu

    if [ "$#" -ne 1 ]; then
      echo "hypr-brightness failed: expected one step arg like 5%+ or 5%-" >&2
      exit 2
    fi

    step="$1"
    fallback=""
    device=""

    for node in /sys/class/backlight/*; do
      [ -e "$node" ] || continue
      name="''${node##*/}"
      if [ -z "$fallback" ]; then
        fallback="$name"
      fi
      case "$name" in
        nvidia_*) ;;
        *)
          device="$name"
          break
          ;;
      esac
    done

    if [ -z "$device" ]; then
      device="$fallback"
    fi

    if [ -z "$device" ]; then
      echo "hypr-brightness failed: no backlight device found under /sys/class/backlight" >&2
      exit 1
    fi

    exec ${brightnessctl} -d "$device" set "$step"
  '';
  muteSound = pkgs.fetchurl {
    url = "https://www.myinstants.com/media/sounds/discordmute_IZNcLx2.mp3";
    sha256 = "4c73fcd425d8dddfef0d2ad970f2fd414be7eb1d190f49b7098e8d638f438039";
  };
  unmuteSound = pkgs.fetchurl {
    url = "https://www.myinstants.com/media/sounds/discord-unmute-sound.mp3";
    sha256 = "b7f6ec23ccabb8183ee2e8073fd4213cffa2241a312bdb1105ee9f0b2cca5576";
  };
  mic-toggle = pkgs.writeShellScriptBin "hypr-mic-toggle" ''
    MUTED=$(${wpctl} get-volume @DEFAULT_AUDIO_SOURCE@ | ${pkgs.gnugrep}/bin/grep -o 'MUTED' || echo "")
    ${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle
    if [ -z "$MUTED" ]; then
      ${pkgs.pipewire}/bin/pw-play --volume=0.2 ${muteSound} &
    else
      ${pkgs.pipewire}/bin/pw-play --volume=0.2 ${unmuteSound} &
    fi
  '';
  # Hyprland silently refuses fullscreen on pinned windows. This wrapper unpins
  # before fullscreening and re-pins when fullscreen is exited, so SUPER+F /
  # SUPER+SHIFT+F work on pinned floating windows like browser PiP.
  smart-fullscreen = pkgs.writeShellScriptBin "hypr-smart-fullscreen" ''
    set -eu
    target="''${1:?usage: hypr-smart-fullscreen <1|2>}"

    state_dir="''${XDG_RUNTIME_DIR:-/tmp}/hypr-fs-repin"
    mkdir -p "$state_dir"

    win=$(${pkgs.hyprland}/bin/hyprctl activewindow -j)
    addr=$(printf '%s' "$win" | ${pkgs.jq}/bin/jq -r '.address')
    pinned=$(printf '%s' "$win" | ${pkgs.jq}/bin/jq -r '.pinned')
    fs=$(printf '%s' "$win" | ${pkgs.jq}/bin/jq -r '.fullscreen')
    marker="$state_dir/$addr"

    if [ "$fs" = "$target" ]; then
      # already at target — exit fullscreen, repin if we unpinned earlier
      if [ -e "$marker" ]; then
        ${pkgs.hyprland}/bin/hyprctl --batch "dispatch fullscreenstate 0 -1 ; dispatch pin address:$addr"
        rm -f "$marker"
      else
        ${pkgs.hyprland}/bin/hyprctl dispatch fullscreenstate "0 -1"
      fi
    elif [ "$fs" != "0" ]; then
      # fullscreen at a different mode — just switch modes, leave pin alone
      ${pkgs.hyprland}/bin/hyprctl dispatch fullscreenstate "$target -1"
    else
      # not fullscreen — unpin if needed, then fullscreen
      if [ "$pinned" = "true" ]; then
        touch "$marker"
        ${pkgs.hyprland}/bin/hyprctl --batch "dispatch pin address:$addr ; dispatch fullscreenstate $target -1"
      else
        ${pkgs.hyprland}/bin/hyprctl dispatch fullscreenstate "$target -1"
      fi
    fi
  '';
in {
  wayland.windowManager.hyprland.settings = {
    # ── Mouse Binds ──
    # SUPER+LMB            Drag to move window
    # SUPER+RMB            Drag to resize window
    # SUPER+CTRL+LMB       Trackpad-friendly resize (1-finger drag)
    bindm = [
      "SUPER,mouse:272,movewindow"
      "SUPER,mouse:273,resizewindow"
      "SUPERCTRL,mouse:272,resizewindow"
    ];

    # ── Resize / Volume / Brightness (hold to repeat) ──
    binde = [
      "Control_L&Shift_L&Alt_L,h,resizeactive,-15 0"
      "Control_L&Shift_L&Alt_L,j,resizeactive,0 15"
      "Control_L&Shift_L&Alt_L,k,resizeactive,0 -15"
      "Control_L&Shift_L&Alt_L,l,resizeactive,15 0"
      ",XF86AudioRaiseVolume,exec,${wpctl} set-volume -l 1.0 @DEFAULT_AUDIO_SINK@ 5%+"
      ",XF86AudioLowerVolume,exec,${wpctl} set-volume @DEFAULT_AUDIO_SINK@ 5%-"
      ",XF86MonBrightnessUp,exec,${brightness-step}/bin/hypr-brightness 5%+"
      ",XF86MonBrightnessDown,exec,${brightness-step}/bin/hypr-brightness 5%-"
    ];

    # ── Mute (trigger on lid/lock too) ──
    bindl = [
      ",XF86AudioMute,exec,${wpctl} set-mute @DEFAULT_AUDIO_SINK@ toggle"
      ",XF86AudioMicMute,exec,${wpctl} set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
    ];

    # ========== Key Binds ==========
    bind = [
      # Quick launch
      "SUPER,Return,exec,$term"
      "CTRL_ALT,v,exec,$term $EDITOR"
      "CTRL_ALT,f,exec,thunar"

      # Mic toggle with sound feedback
      "SUPER,m,exec,${mic-toggle}/bin/hypr-mic-toggle"

      # Media controls
      ",XF86AudioPlay,exec,playerctl --ignore-player=firefox,chromium,brave play-pause"
      ",XF86AudioNext,exec,playerctl --ignore-player=firefox,chromium,brave next"
      ",XF86AudioPrev,exec,playerctl --ignore-player=firefox,chromium,brave previous"

      # ── Window Management ──
      # SUPER+F             Maximize (keeps bar)
      # SUPER+SHIFT+F       True fullscreen (hides bar)
      # SUPER+B             Toggle floating
      # SUPER+SHIFT+P       Pin window (stays on all workspaces)
      "SUPER,f,exec,${smart-fullscreen}/bin/hypr-smart-fullscreen 1"
      "SUPERSHIFT,F,exec,${smart-fullscreen}/bin/hypr-smart-fullscreen 2"
      "SUPER,b,togglefloating"
      "SUPERSHIFT,p,pin,active"

      # ── Window Groups ──
      # SUPER+'              Next tab in group
      # SUPER+SHIFT+'        Previous tab in group
      "SUPER,apostrophe,changegroupactive,f"
      "SUPERSHIFT,apostrophe,changegroupactive,b"

      # Workspace management
      "SUPER,0,workspace,10"
      "SUPER,1,workspace,1"
      "SUPER,2,workspace,2"
      "SUPER,3,workspace,3"
      "SUPER,4,workspace,4"
      "SUPER,5,workspace,5"
      "SUPER,6,workspace,6"
      "SUPER,7,workspace,7"
      "SUPER,8,workspace,8"
      "SUPER,9,workspace,9"
      "SUPER,F1,workspace,name:F1"
      "SUPER,F2,workspace,name:F2"
      "SUPER,F3,workspace,name:F3"
      "SUPER,F4,workspace,name:F4"
      "SUPER,F5,workspace,name:F5"
      "SUPER,F6,workspace,name:F6"
      "SUPER,F7,workspace,name:F7"
      "SUPER,F8,workspace,name:F8"
      "SUPER,F9,workspace,name:F9"
      "SUPER,F10,workspace,name:F10"
      "SUPER,F11,workspace,name:F11"
      "SUPER,F12,workspace,name:F12"

      # Special workspace
      "SUPER,y,togglespecialworkspace"
      "SUPERSHIFT,y,movetoworkspace,special"

      # ── Monitor Workspace Movement ──
      # SUPER+CTRL+{h,j,k,l}    Move workspace to monitor left/down/up/right
      # SUPER+CTRL+{arrows}      Move workspace to monitor left/down/up/right
      "SUPERCTRL,left,movecurrentworkspacetomonitor,l"
      "SUPERCTRL,right,movecurrentworkspacetomonitor,r"
      "SUPERCTRL,up,movecurrentworkspacetomonitor,u"
      "SUPERCTRL,down,movecurrentworkspacetomonitor,d"
      "SUPERCTRL,h,movecurrentworkspacetomonitor,l"
      "SUPERCTRL,l,movecurrentworkspacetomonitor,r"
      "SUPERCTRL,k,movecurrentworkspacetomonitor,u"
      "SUPERCTRL,j,movecurrentworkspacetomonitor,d"

      # System controls
      "SUPERSHIFT,e,exit,"

      # Screen annotation (wayscriber)
      "SUPER,a,exec,${pkgs.procps}/bin/pkill -SIGUSR1 wayscriber"

      # ── Monitor Focus ──
      # SUPER+,/.            Focus monitor left/right
      "SUPER,comma,focusmonitor,l"
      "SUPER,period,focusmonitor,r"

      # ── Screenshots ──
      # PRINT               Screenshot current monitor
      # SUPER+PRINT         Screenshot region
      ",PRINT,exec,${hyprshot} -m output"
      "SUPER,PRINT,exec,${hyprshot} -m region"

      # ── GPU Screen Recorder ──
      # SUPER+X              Save replay (last 60s)
      "SUPER,x,exec,save-gsr-replay"
    ];
  };
}
