{config, ...}: let
  c = config.lib.stylix.colors.withHashtag;
  lnavStylixTheme =
    (builtins.fromJSON (builtins.readFile ./stylix-theme.json))
    // {
      vars = {
        background = c.base00;
        bglighter = c.base02;
        bglight = c.base01;
        bgdark = c.base00;
        bgdarker = c.base00;
        foreground = c.base05;
        selection = c.base02;
        # base03/base04 are too dim on base00; match nixvim's comment fix
        # (catppuccin overlay2, not in the 16-colour set).
        comment = "#9399b2";
        black = c.base00;
        red = c.base08;
        green = c.base0B;
        yellow = c.base0A;
        blue = c.base0D;
        magenta = c.base0E;
        cyan = c.base0C;
        white = c.base05;
        orange = c.base09;
        purple = c.base0E;
        pink = c.base0E;
        semantic_highlight_color = "semantic()";
      };
    };
in {
  programs.lnav.settings.ui = {
    theme = "stylix";
    theme-defs.stylix = lnavStylixTheme;
  };
}
