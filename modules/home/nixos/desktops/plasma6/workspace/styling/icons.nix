{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.plasma.workspace.styling.icons;

  iconThemes = {
    papirus-dark = {
      package = pkgs.papirus-icon-theme;
      themeName = "Papirus-Dark";
    };
    papirus = {
      package = pkgs.papirus-icon-theme;
      themeName = "Papirus";
    };
    papirus-light = {
      package = pkgs.papirus-icon-theme;
      themeName = "Papirus-Light";
    };
    breeze = {
      package = null;
      themeName = "breeze";
    };
    breeze-dark = {
      package = null;
      themeName = "breeze-dark";
    };
  };

  currentTheme = iconThemes.${cfg.theme} or iconThemes.breeze;
in {
  options.programs.plasma.workspace.styling.icons = {
    theme = mkOption {
      type = types.enum (attrNames iconThemes);
      default = "breeze";
      description = "Icon theme to use";
    };
  };

  config = mkMerge [
    (mkIf (currentTheme.package != null) {
      home.file = {
        ".local/share/icons/${currentTheme.themeName}".source = "${currentTheme.package}/share/icons/${currentTheme.themeName}";
      };
    })

    {
      programs.plasma.workspace.iconTheme = currentTheme.themeName;
    }
  ];
}
