_: {
  programs.niri.settings.binds = {
    # Terminal
    "Mod+Return".action.spawn = "ghostty";

    # Close window (Hyprland's key)
    "Mod+Shift+Q".action.close-window = {};

    "Mod+B".action.toggle-window-floating = {};

    # Navigation
    "Mod+Left".action.focus-column-left = {};
    "Mod+Right".action.focus-column-right = {};
    "Mod+Up".action.focus-window-up = {};
    "Mod+Down".action.focus-window-down = {};
    "Mod+H".action.focus-column-left = {};
    "Mod+L".action.focus-column-right = {};
    "Mod+K".action.focus-window-up = {};
    "Mod+J".action.focus-window-down = {};

    # Move windows
    "Mod+Shift+Left".action.move-column-left = {};
    "Mod+Shift+Right".action.move-column-right = {};
    "Mod+Shift+Up".action.move-window-up = {};
    "Mod+Shift+Down".action.move-window-down = {};
    "Mod+Shift+H".action.move-column-left = {};
    "Mod+Shift+L".action.move-column-right = {};
    "Mod+Shift+K".action.move-window-up = {};
    "Mod+Shift+J".action.move-window-down = {};

    # Sizing
    "Mod+F".action.maximize-column = {};
    "Mod+Shift+F".action.fullscreen-window = {};
    "Mod+R".action.switch-preset-column-width = {};
    "Mod+Minus".action.set-column-width = "-10%";
    "Mod+Equal".action.set-column-width = "+10%";
    # Hyprland's resize keys, in logical pixels.
    "Ctrl+Shift+Alt+H".action.set-column-width = "-15";
    "Ctrl+Shift+Alt+L".action.set-column-width = "+15";
    "Ctrl+Shift+Alt+K".action.set-window-height = "-15";
    "Ctrl+Shift+Alt+J".action.set-window-height = "+15";

    # Overview
    "Mod+O".action.toggle-overview = {};

    # Workspaces
    "Mod+1".action.focus-workspace = 1;
    "Mod+2".action.focus-workspace = 2;
    "Mod+3".action.focus-workspace = 3;
    "Mod+4".action.focus-workspace = 4;
    "Mod+5".action.focus-workspace = 5;
    "Mod+6".action.focus-workspace = 6;
    "Mod+7".action.focus-workspace = 7;
    "Mod+8".action.focus-workspace = 8;
    "Mod+9".action.focus-workspace = 9;
    "Mod+0".action.focus-workspace = 10;
    "Mod+Shift+1".action.move-column-to-workspace = 1;
    "Mod+Shift+2".action.move-column-to-workspace = 2;
    "Mod+Shift+3".action.move-column-to-workspace = 3;
    "Mod+Shift+4".action.move-column-to-workspace = 4;
    "Mod+Shift+5".action.move-column-to-workspace = 5;
    "Mod+Shift+6".action.move-column-to-workspace = 6;
    "Mod+Shift+7".action.move-column-to-workspace = 7;
    "Mod+Shift+8".action.move-column-to-workspace = 8;
    "Mod+Shift+9".action.move-column-to-workspace = 9;
    "Mod+Shift+0".action.move-column-to-workspace = 10;

    # Scroll through workspaces
    "Mod+Page_Down".action.focus-workspace-down = {};
    "Mod+Page_Up".action.focus-workspace-up = {};

    # Monitors
    "Mod+Comma".action.focus-monitor-left = {};
    "Mod+Period".action.focus-monitor-right = {};
    "Mod+Ctrl+Left".action.move-workspace-to-monitor-left = {};
    "Mod+Ctrl+Right".action.move-workspace-to-monitor-right = {};
    "Mod+Ctrl+Up".action.move-workspace-to-monitor-up = {};
    "Mod+Ctrl+Down".action.move-workspace-to-monitor-down = {};
    "Mod+Ctrl+H".action.move-workspace-to-monitor-left = {};
    "Mod+Ctrl+L".action.move-workspace-to-monitor-right = {};
    "Mod+Ctrl+K".action.move-workspace-to-monitor-up = {};
    "Mod+Ctrl+J".action.move-workspace-to-monitor-down = {};
    "Mod+Shift+Ctrl+Left".action.move-column-to-monitor-left = {};
    "Mod+Shift+Ctrl+Right".action.move-column-to-monitor-right = {};

    # Screenshot
    # Hyprland's layout: Print saves the whole monitor at once, Mod+Print picks a region.
    "Print".action.screenshot-screen = {};
    "Mod+Print".action.screenshot = {};
    "Shift+Print".action.screenshot-window = {};

    # Session: Hyprland's four-modifier chord, so a slip can't reach it.
    "Mod+Ctrl+Shift+Alt+Delete".action.quit = {};

    # Apps
    "Ctrl+Alt+V".action.spawn-sh = "ghostty -e $EDITOR";

    # Take the focused window into the column on its left, or back out of it.
    "Mod+T".action.consume-or-expel-window-left = {};
  };
}
