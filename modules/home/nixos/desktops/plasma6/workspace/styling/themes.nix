{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.plasma.workspace.styling.themes;
in {
  options.programs.plasma.workspace.styling.themes = {
    whitesur = {
      enable = mkEnableOption "WhiteSur KDE theme";

      variant = mkOption {
        type = types.enum ["standard" "alt" "dark"];
        default = "standard";
        description = "WhiteSur theme variant to use";
      };

      windowDecoration = mkOption {
        type = types.enum ["default" "sharp" "opaque"];
        default = "default";
        description = "Window decoration style";
      };
    };
  };

  config = mkIf cfg.whitesur.enable {
    programs.plasma = {
      workspace = {
        lookAndFeel = mkDefault (
          if cfg.whitesur.variant == "dark"
          then "com.github.vinceliuice.WhiteSur-dark"
          else if cfg.whitesur.variant == "alt"
          then "com.github.vinceliuice.WhiteSur-alt"
          else "com.github.vinceliuice.WhiteSur"
        );

        colorScheme = mkDefault (
          if cfg.whitesur.variant == "dark"
          then "WhiteSurDark"
          else if cfg.whitesur.variant == "alt"
          then "WhiteSurAlt"
          else "WhiteSur"
        );

        theme = mkDefault (
          if cfg.whitesur.variant == "dark"
          then "WhiteSur-dark"
          else if cfg.whitesur.variant == "alt"
          then "WhiteSur-alt"
          else "WhiteSur"
        );
      };
    };

    # Configure window decorations through config file
    programs.plasma.configFile.kwinrc."org.kde.kdecoration2" = mkDefault {
      library = let
        decorationName =
          if cfg.whitesur.variant == "dark"
          then "WhiteSur-dark"
          else "WhiteSur";
        windowStyle =
          if cfg.whitesur.windowDecoration == "sharp"
          then "-sharp"
          else if cfg.whitesur.windowDecoration == "opaque"
          then "-opaque"
          else "";
      in "org.kde.kwin.aurorae__aurorae__svg__${decorationName}${windowStyle}";
      theme = "__aurorae__svg__${
        let
          decorationName =
            if cfg.whitesur.variant == "dark"
            then "WhiteSur-dark"
            else "WhiteSur";
          windowStyle =
            if cfg.whitesur.windowDecoration == "sharp"
            then "-sharp"
            else if cfg.whitesur.windowDecoration == "opaque"
            then "-opaque"
            else "";
        in "${decorationName}${windowStyle}"
      }";
    };

    # Symlink theme files to where KDE expects them
    xdg.dataFile = {
      # Color schemes
      "color-schemes/WhiteSur.colors".source = "${pkgs.whitesur-kde}/share/color-schemes/WhiteSur.colors";
      "color-schemes/WhiteSurAlt.colors".source = "${pkgs.whitesur-kde}/share/color-schemes/WhiteSurAlt.colors";
      "color-schemes/WhiteSurDark.colors".source = "${pkgs.whitesur-kde}/share/color-schemes/WhiteSurDark.colors";

      # Desktop themes
      "plasma/desktoptheme/WhiteSur".source = "${pkgs.whitesur-kde}/share/plasma/desktoptheme/WhiteSur";
      "plasma/desktoptheme/WhiteSur-alt".source = "${pkgs.whitesur-kde}/share/plasma/desktoptheme/WhiteSur-alt";
      "plasma/desktoptheme/WhiteSur-dark".source = "${pkgs.whitesur-kde}/share/plasma/desktoptheme/WhiteSur-dark";

      # Look and feel themes
      "plasma/look-and-feel/com.github.vinceliuice.WhiteSur".source = "${pkgs.whitesur-kde}/share/plasma/look-and-feel/com.github.vinceliuice.WhiteSur";
      "plasma/look-and-feel/com.github.vinceliuice.WhiteSur-alt".source = "${pkgs.whitesur-kde}/share/plasma/look-and-feel/com.github.vinceliuice.WhiteSur-alt";
      "plasma/look-and-feel/com.github.vinceliuice.WhiteSur-dark".source = "${pkgs.whitesur-kde}/share/plasma/look-and-feel/com.github.vinceliuice.WhiteSur-dark";
    };
  };
}
