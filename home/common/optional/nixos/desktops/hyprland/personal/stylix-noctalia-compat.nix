# Stylix -> Noctalia theming shim. Stylix's bundled noctalia target targets a
# different option than we use and silently emits nothing, so we reproduce it
# from `config.lib.stylix.colors` / `config.stylix`: colors via a `custom`
# palette, plus font and background opacity. Delete this file (and its import in
# ./default.nix) if stylix ever themes noctalia natively.
{config, ...}: {
  programs.noctalia = {
    customPalettes.stylix = let
      roles = with config.lib.stylix.colors.withHashtag; {
        mPrimary = base0D;
        mOnPrimary = base00;
        mSecondary = base0E;
        mOnSecondary = base00;
        mTertiary = base0C;
        mOnTertiary = base00;
        mError = base08;
        mOnError = base00;
        mSurface = base00;
        mOnSurface = base05;
        mSurfaceVariant = base01;
        mOnSurfaceVariant = base04;
        mOutline = base03;
        mShadow = base00;
        mHover = base0C;
        mOnHover = base00;

        # A `terminal` block is mandatory — the palette parser rejects a mode
        # without one. Standard base16 -> ANSI mapping.
        terminal = {
          normal = {
            black = base00;
            red = base08;
            green = base0B;
            yellow = base0A;
            blue = base0D;
            magenta = base0E;
            cyan = base0C;
            white = base05;
          };
          bright = {
            black = base03;
            red = base08;
            green = base0B;
            yellow = base0A;
            blue = base0D;
            magenta = base0E;
            cyan = base0C;
            white = base07;
          };
          foreground = base05;
          background = base00;
          cursor = base05;
          cursorText = base00;
          selectionFg = base05;
          selectionBg = base02;
        };
      };
    in {
      # base16 is a single (dark) scheme; mirror into light so theme.mode
      # changes don't fall back to an empty palette.
      dark = roles;
      light = roles;
    };

    settings = {
      theme = {
        source = "custom";
        custom_palette = "stylix";
        mode = "dark"; # tracks stylix.polarity = "dark"
      };

      # stylix sansSerif (Inter).
      shell.font_family = config.stylix.fonts.sansSerif.name;

      # stylix opacity.popups (0.85) -> frosted OSD/notifications;
      # opacity.desktop (1.0) -> opaque bar.
      osd.background_opacity = config.stylix.opacity.popups;
      notification.background_opacity = config.stylix.opacity.popups;
      bar.main.background_opacity = config.stylix.opacity.desktop;
    };
  };
}
