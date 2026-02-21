{pkgs, ...}: let
  hyprshot = "${pkgs.hyprshot}/bin/hyprshot";
in {
  wayland.windowManager.hyprland.settings = {
    # ── Mouse Binds ──
    # SUPER+LMB            Drag to move window
    # SUPER+RMB            Drag to resize window
    bindm = [
      "SUPER,mouse:272,movewindow"
      "SUPER,mouse:273,resizewindow"
    ];

    # ── Resize (hold to repeat) ──
    # CTRL+SHIFT+ALT+{h,j,k,l}  Resize active window
    binde = [
      "Control_L&Shift_L&Alt_L,h,resizeactive,-15 0"
      "Control_L&Shift_L&Alt_L,j,resizeactive,0 15"
      "Control_L&Shift_L&Alt_L,k,resizeactive,0 -15"
      "Control_L&Shift_L&Alt_L,l,resizeactive,15 0"
    ];

    # ========== Key Binds ==========
    bind = [
      # Quick launch
      "SUPER,Return,exec,$term"
      "CTRL_ALT,v,exec,$term $EDITOR"
      "CTRL_ALT,f,exec,thunar"

      # Media controls
      ",XF86AudioPlay,exec,playerctl --ignore-player=firefox,chromium,brave play-pause"
      ",XF86AudioNext,exec,playerctl --ignore-player=firefox,chromium,brave next"
      ",XF86AudioPrev,exec,playerctl --ignore-player=firefox,chromium,brave previous"

      # ── Window Management ──
      # SUPER+F             Maximize (keeps bar)
      # SUPER+SHIFT+F       True fullscreen (hides bar)
      # SUPER+B             Toggle floating
      # SUPER+SHIFT+P       Pin window (stays on all workspaces)
      "SUPER,f,fullscreenstate,1 -1"
      "SUPERSHIFT,F,fullscreenstate,2 -1"
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
      # CTRL+SHIFT+{h,j,k,l}    Move workspace to monitor left/down/up/right
      # CTRL+SHIFT+{arrows}      Move workspace to monitor left/down/up/right
      "CTRLSHIFT,left,movecurrentworkspacetomonitor,l"
      "CTRLSHIFT,right,movecurrentworkspacetomonitor,r"
      "CTRLSHIFT,up,movecurrentworkspacetomonitor,u"
      "CTRLSHIFT,down,movecurrentworkspacetomonitor,d"
      "CTRLSHIFT,h,movecurrentworkspacetomonitor,l"
      "CTRLSHIFT,l,movecurrentworkspacetomonitor,r"
      "CTRLSHIFT,k,movecurrentworkspacetomonitor,u"
      "CTRLSHIFT,j,movecurrentworkspacetomonitor,d"

      # System controls
      "SUPER,escape,exec,hyprlock"
      "SUPERSHIFT,e,exit,"

      # Screen annotation (wayscriber)
      "SUPER,a,exec,${pkgs.procps}/bin/pkill -SIGUSR1 wayscriber"

      # Sunshine: restore physical monitors (safety keybind)
      "SUPERSHIFT,s,exec,sunshine-disconnect"

      # Fcitx5 restart
      "ALT,E,exec,pkill fcitx5 -9;sleep 1;fcitx5 -d --replace; sleep 1;fcitx5-remote -r"

      # ── Monitor Focus ──
      # SUPER+,/.            Focus monitor left/right
      "SUPER,comma,focusmonitor,l"
      "SUPER,period,focusmonitor,r"

      # ── Screenshots ──
      # PRINT               Screenshot current monitor
      # SUPER+PRINT         Screenshot region
      ",PRINT,exec,${hyprshot} -m output"
      "SUPER,PRINT,exec,${hyprshot} -m region"
    ];
  };
}
