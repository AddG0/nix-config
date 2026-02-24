{
  pkgs,
  config,
  ...
}: let
  c = config.lib.stylix.colors;
in {
  wayland.windowManager.hyprland = {
    plugins = [pkgs.hyprlandPlugins.hy3];
    settings = {
      general.layout = "hy3";

      plugin.hy3 = {
        enable = true;
        tabs = {
          height = 28;
          padding = 8;
          radius = 8;
          border_width = 2;
          render_text = true;
          text_center = true;
          text_font = "Inter";
          text_height = 10;
          text_padding = 6;

          "col.active" = "rgba(${c.base0D}20)";
          "col.active.border" = "rgba(${c.base0D}88)";
          "col.active.text" = "rgba(${c.base05}ff)";

          "col.focused" = "rgba(${c.base02}80)";
          "col.focused.border" = "rgba(${c.base03}cc)";
          "col.focused.text" = "rgba(${c.base05}ff)";

          "col.inactive" = "rgba(${c.base00}60)";
          "col.inactive.border" = "rgba(${c.base02}88)";
          "col.inactive.text" = "rgba(${c.base04}ff)";

          "col.urgent" = "rgba(${c.base08}80)";
          "col.urgent.border" = "rgba(${c.base08}ee)";
          "col.urgent.text" = "rgba(${c.base05}ff)";

          blur = true;
          opacity = 0.95;
        };
      };

      # ── hy3 Binds ──
      bindn = [
        ",mouse:272,hy3:focustab,mouse"
      ];
      bind = [
        # Window management
        "SUPERSHIFT,q,hy3:killactive"

        # Groups
        "SUPER,v,hy3:makegroup,v"
        "SUPERSHIFT,v,hy3:makegroup,h"
        "SUPER,s,hy3:changegroup,opposite"
        "SUPER,g,hy3:changegroup,toggletab"

        # Focus
        "SUPER,left,hy3:movefocus,l,warp"
        "SUPER,right,hy3:movefocus,r,warp"
        "SUPER,up,hy3:movefocus,u,warp"
        "SUPER,down,hy3:movefocus,d,warp"
        "SUPER,h,hy3:movefocus,l,warp"
        "SUPER,l,hy3:movefocus,r,warp"
        "SUPER,k,hy3:movefocus,u,warp"
        "SUPER,j,hy3:movefocus,d,warp"

        # Move window
        "SUPERSHIFT,left,hy3:movewindow,l"
        "SUPERSHIFT,right,hy3:movewindow,r"
        "SUPERSHIFT,up,hy3:movewindow,u"
        "SUPERSHIFT,down,hy3:movewindow,d"
        "SUPERSHIFT,h,hy3:movewindow,l"
        "SUPERSHIFT,l,hy3:movewindow,r"
        "SUPERSHIFT,k,hy3:movewindow,u"
        "SUPERSHIFT,j,hy3:movewindow,d"

        # Move to workspace
        "SUPERSHIFT,0,hy3:movetoworkspace,10"
        "SUPERSHIFT,1,hy3:movetoworkspace,1"
        "SUPERSHIFT,2,hy3:movetoworkspace,2"
        "SUPERSHIFT,3,hy3:movetoworkspace,3"
        "SUPERSHIFT,4,hy3:movetoworkspace,4"
        "SUPERSHIFT,5,hy3:movetoworkspace,5"
        "SUPERSHIFT,6,hy3:movetoworkspace,6"
        "SUPERSHIFT,7,hy3:movetoworkspace,7"
        "SUPERSHIFT,8,hy3:movetoworkspace,8"
        "SUPERSHIFT,9,hy3:movetoworkspace,9"
        "SUPERSHIFT,F1,hy3:movetoworkspace,name:F1"
        "SUPERSHIFT,F2,hy3:movetoworkspace,name:F2"
        "SUPERSHIFT,F3,hy3:movetoworkspace,name:F3"
        "SUPERSHIFT,F4,hy3:movetoworkspace,name:F4"
        "SUPERSHIFT,F5,hy3:movetoworkspace,name:F5"
        "SUPERSHIFT,F6,hy3:movetoworkspace,name:F6"
        "SUPERSHIFT,F7,hy3:movetoworkspace,name:F7"
        "SUPERSHIFT,F8,hy3:movetoworkspace,name:F8"
        "SUPERSHIFT,F9,hy3:movetoworkspace,name:F9"
        "SUPERSHIFT,F10,hy3:movetoworkspace,name:F10"
        "SUPERSHIFT,F11,hy3:movetoworkspace,name:F11"
        "SUPERSHIFT,F12,hy3:movetoworkspace,name:F12"
      ];
    };
  };
}
