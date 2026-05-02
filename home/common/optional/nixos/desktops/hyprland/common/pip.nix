{
  # Picture-in-Picture: float, pin across workspaces, park top-right.
  # Title matches Firefox and Chromium-based browsers.
  wayland.windowManager.hyprland.settings.windowrule = [
    "float on, match:title ^(Picture[- ]in[- ][Pp]icture)$"
    "pin on, match:title ^(Picture[- ]in[- ][Pp]icture)$"
    "size 960 540, match:title ^(Picture[- ]in[- ][Pp]icture)$"
    # Top-right with 20px margin. Uses Hyprland windowrule expression vars
    # (monitor_w / window_w) — not the 100%-w-N syntax, which only works in
    # `dispatch movewindowpixel`, not in `windowrule = move`.
    "move (monitor_w-window_w-20) 20, match:title ^(Picture[- ]in[- ][Pp]icture)$"
    # Override global inactive_opacity so PiP stays fully opaque while unfocused.
    "opacity 1.0 override 1.0 override, match:title ^(Picture[- ]in[- ][Pp]icture)$"
  ];
}
