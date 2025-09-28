#
# Dunst
# Notifcation Daemon
#
{
  pkgs,
  lib,
  ...
}: {
  home.packages = builtins.attrValues {
    inherit (pkgs) libnotify; # required by dunst
  };

  services.dunst = {
    enable = true;
    #    waylandDisplay = ""; # set the service's WAYLAND_DISPLAY environment variable
    #    configFile = "";
    iconTheme = {
      name = "Adwaita";
      package = pkgs.adwaita-icon-theme;
      size = "48x48"; # Increased icon size for better visibility
    };
    settings = {
      global = {
        # Allow a small subset of html markup:<b></b>, <i></i>, <s></s>, and <u></u>.
        # For a complete reference see
        # <http://developer.gnome.org/pango/stable/PangoMarkupFormat.html>.
        # If markup is not allowed, those tags will be stripped out of the message.
        allow_markup = "yes";

        # The format of the message.  Possible variables are:
        #   %a  appname
        #   %s  summary
        #   %b  body
        #   %i  iconname (including its path)
        #   %I  iconname (without its path)
        #   %p  progress value if set ([  0%] to [100%]) or nothing
        # Markup is allowed
        format = "<b>%s</b>\n%b"; # Include both title and body

        #TODO dynamic fonts
        #font = "SF Pro Display 12"; # Apple-like font
        alignment = "left"; # Apple notifications are left-aligned

        sort = "yes";
        indicate_hidden = "yes";

        show_age_threshold = 60;

        word_wrap = "true"; # Enable word wrap for cleaner text

        ignore_newline = "no";

        # Geometry adjusted for more Apple-like appearance
        width = 400; # Wider notifications
        height = "(60, 300)"; # Increased height to accommodate stacked notifications
        offset = "20x20"; # Reduced top offset
        origin = "top-right";

        # Shrink window if it's smaller than the width.
        shrink = "yes";

        follow = "mouse";

        sticky_history = "yes";
        history_length = 20;

        show_indicators = "no"; # Hide URL/action indicators for cleaner look

        line_height = 4; # Increased line spacing

        # Reduced padding for more compact feel
        padding = 8;
        horizontal_padding = 12;
        gap_size = 4; # Gap between different notifications

        # Semi-transparent white background like Apple
        transparency = 10;

        startup_notification = false;

        # Icon settings
        icon_position = "left";
        min_icon_size = 48; # Minimum icon size
        max_icon_size = 48; # Maximum icon size to maintain consistency
        icon_corner_radius = 12; # Round the app icons

        # Rounded corners - ensure they stay rounded when stacked
        corner_radius = 15; # More pronounced rounding
        progress_bar_corner_radius = 15; # Match notification corners
        force_xinerama = false; # Better multi-monitor support
        force_xwayland = false; # Better Wayland support

        # Browser for opening urls in context menu
        browser = "${pkgs.zen-browser}/bin/zen-browser";

        # Enable mouse actions
        mouse_left_click = "do_action";
        mouse_middle_click = "close_current";
        mouse_right_click = "close_all";

        # Apple-style background and text colors
        background = lib.mkForce "#1E1E1E"; # rgba(255,255,255,0.18) converted to hex
        foreground = lib.mkForce "#FFFFFF";

        # Stack identical notifications with no gap, different notifications have gaps
        stack_duplicates = true;
        hide_duplicate_count = true;

        # Remove colored border
        frame_width = 0;
      };

      shortcuts = {
        close = "mod1+space";
        close_all = "ctrl+mod1+space";
        history = "ctrl+mod4+h";
        context = "ctrl+mod1+c";
      };

      urgency_low = {
        background = lib.mkForce "#2E2E2E"; # Slightly lighter for low urgency
        foreground = lib.mkForce "#FFFFFF";
        timeout = 5;
      };

      urgency_normal = {
        background = lib.mkForce "#1E1E1E"; # Base dark color for normal
        foreground = lib.mkForce "#FFFFFF";
        timeout = 7;
      };

      urgency_critical = {
        background = lib.mkForce "#3E1E1E"; # Darker red tint for critical
        foreground = lib.mkForce "#FFFFFF";
        timeout = 0;
      };
    };
  };
}
