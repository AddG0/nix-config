# Steam's Hyprland window rules.
{
  config,
  lib,
  ...
}: let
  primaryMonitor = lib.findFirst (m: m.primary) null config.display.monitors;
in
  lib.mkIf config.wayland.windowManager.hyprland.enable {
    wayland.windowManager.hyprland.settings.windowrule =
      [
        # Steam maps this dialog as a normal window, so it tiles full-height.
        "float on, match:class ^([Ss]team)$, match:title ^(Authorize Device)$"
        "center 1, match:class ^([Ss]team)$, match:title ^(Authorize Device)$"
        "float on, match:title ^(ProtonFixes)$"
        # Terraria's blank launcher helper.
        "workspace special silent, match:class ^(steam_app_252950)$, match:title ^$"
        "workspace special silent, match:title (Lethal Company.*\\.exe)"
      ]
      # Steam toasts ignore the X11 primary; pin them to the primary's corner.
      # Without "silent" the toast mapping there drags the cursor along with it.
      ++ lib.optionals (primaryMonitor != null) [
        "float on, match:title ^(notificationtoasts.*)$"
        "monitor ${primaryMonitor.output} silent, match:title ^(notificationtoasts.*)$"
        "move 100%-w-20 100%-h-20, match:title ^(notificationtoasts.*)$"
      ];
  }
