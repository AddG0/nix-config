# noctalia-greeter on greetd as the login screen, matching the Noctalia shell and hyprlock.
#
# Cursor, palette and font come from stylix and the output layout from the host's
# display.monitors. On an OLED host it goes hyprlock's OLED way: black, the password
# field alone for the primary user, and the panel blanked when idle.
{
  inputs,
  config,
  lib,
  ...
}: let
  # Empty in a specialisation that drops its homes; those carry the parent's settings instead.
  primaryUser = config.home-manager.users.${config.hostSpec.primaryUsername} or {};
  # The system stylix cursor if set, else the primary user's; null leaves the greeter's default.
  systemCursor = config.stylix.cursor or null;
  cursor =
    if systemCursor != null
    then systemCursor
    else primaryUser.stylix.cursor or null;
  stylixEnabled = primaryUser.stylix.enable or false;
  monitors = lib.filter (m: m.enabled) config.display.monitors;
  oledMonitors = lib.filter (m: m.oled) monitors;
  perOutput = f: lib.concatMapStringsSep "; " (m: "${m.output}:${f m}") monitors;
  black = "#000000";

  # The M3 roles hyprlock and visuals.nix take from base16.
  palette = let
    c = primaryUser.lib.stylix.colors.withHashtag;
  in
    {
      primary = c.base0D;
      on_primary = c.base00;
      secondary = c.base0E;
      on_secondary = c.base00;
      tertiary = c.base0A;
      on_tertiary = c.base00;
      error = c.base08;
      on_error = c.base00;
      surface = c.base00;
      on_surface = c.base05;
      surface_variant = c.base02;
      on_surface_variant = primaryUser.lib.palette.muted.text;
      outline = c.base04;
      shadow = black;
      hover = c.base03;
      on_hover = c.base05;
    }
    # The login card and field fill are surface_variant; black leaves only the outline and dots lit.
    // lib.optionalAttrs (oledMonitors != []) {
      surface = black;
      surface_variant = black;
    };
in {
  imports = [
    inputs.noctalia-greeter.nixosModules.default
    ./_greetd.nix
    (import ./_retain-splash.nix {})
  ];

  services.displayManager.noctalia-greeter = {
    enable = true;
    settings = lib.mkMerge [
      {
        cursor = lib.mkIf (cursor != null) {
          theme = cursor.name;
          inherit (cursor) size;
          path = cursor.package;
        };
        output = lib.mkIf (monitors != []) {
          layout = perOutput (m: "${toString m.x},${toString m.y}");
          transforms = perOutput (m: m.transform);
          scales = perOutput (m: toString m.scale);
          refresh_rate = perOutput (m: toString m.refreshRate);
        };
        appearance = lib.mkIf stylixEnabled {
          scheme = "Synced";
          theme_mode = "dark";
          font_family = primaryUser.stylix.fonts.sansSerif.name;
          inherit palette;
        };
      }
      (lib.mkIf (oledMonitors != []) {
        user.default = config.hostSpec.primaryUsername;
        appearance = {
          hide_logo = true;
          power_buttons_position = "hidden";
          scheme_selector_position = "hidden";
          # Per-output, so a wallpaper from the shell's "Sync Now" can't light the panel.
          wallpapers = lib.listToAttrs (map (m: lib.nameValuePair m.output {path = "color:${black}";}) oledMonitors);
        };
        clock.enabled = false;
        # Nobody reads a login screen; blank well before hypridle's 240s, since it is lit edge to edge.
        idle.timeout = 30;
      })
    ];
  };

  # The greeter user only sees system fonts; stylix installs this one per user.
  fonts.packages = lib.mkIf stylixEnabled [primaryUser.stylix.fonts.sansSerif.package];
}
