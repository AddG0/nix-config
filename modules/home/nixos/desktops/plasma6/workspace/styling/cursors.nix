{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.plasma.workspace.styling.cursors;

  cursorThemes = {
    bibata = {
      variants = {
        "Modern-Classic" = {
          packageName = "Bibata-Modern-Classic";
          themeName = "Bibata-Modern-Classic";
        };
        "Modern-Ice" = {
          packageName = "Bibata-Modern-Ice";
          themeName = "Bibata-Modern-Ice";
        };
        "Original-Classic" = {
          packageName = "Bibata-Original-Classic";
          themeName = "Bibata-Original-Classic";
        };
        "Original-Ice" = {
          packageName = "Bibata-Original-Ice";
          themeName = "Bibata-Original-Ice";
        };
      };
      package = pkgs.bibata-cursors;
    };
    vimix = {
      variants = {
        dark = {
          packageName = "Vimix-cursors";
          themeName = "Vimix-cursors";
        };
        white = {
          packageName = "Vimix-white-cursors";
          themeName = "Vimix-white-cursors";
        };
      };
      package = pkgs.vimix-cursors;
    };
    default = {
      variants = {
        breeze = {
          packageName = null;
          themeName = "breeze_cursors";
        };
      };
      package = null;
    };
  };

  currentTheme = cursorThemes.${cfg.theme} or cursorThemes.default;
  currentVariant =
    if cfg.variant != "" && currentTheme.variants ? ${cfg.variant}
    then currentTheme.variants.${cfg.variant}
    else head (attrValues currentTheme.variants);
in {
  options.programs.plasma.workspace.styling.cursors = {
    theme = mkOption {
      type = types.enum (attrNames cursorThemes);
      default = "default";
      description = "Cursor theme to use";
    };

    variant = mkOption {
      type = types.str;
      default = "";
      description = "Variant of the cursor theme. Available variants depend on the selected theme.";
    };

    size = mkOption {
      type = types.int;
      default = 24;
      description = "Cursor size";
    };
  };

  config = mkMerge [
    (mkIf (cfg.theme != "default" && currentTheme.package != null) {
      home.file = let
        iconPath = "${currentTheme.package}/share/icons/${currentVariant.packageName}";
      in {
        ".local/share/icons/${currentVariant.packageName}" = {
          source = iconPath;
        };
      };
    })

    {
      programs.plasma.workspace.cursor = {
        theme = currentVariant.themeName;
        size = cfg.size;
      };
    }
  ];
}
