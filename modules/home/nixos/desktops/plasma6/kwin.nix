{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.plasma.kwin;
in {
  options.programs.plasma.kwin = {
    scripts = {
      geometryChange = {
        enable = mkEnableOption "Geometry Change KWin effect";
      };

      squash = {
        enable = mkEnableOption "Squash KWin effect";
      };

      kzone = {
        enable = mkEnableOption "KZones window management script";
      };
    };
  };

  config = mkMerge [
    (mkIf cfg.scripts.geometryChange.enable {
      home.file = {
        ".local/share/kwin/effects/kwin4_effect_geometry_change" = {
          source = "${pkgs.kwin-scripts.kwin4-effect-geometry-change}/share/kwin/effects";
          recursive = true;
        };
      };

      programs.plasma.configFile.kwinrc.Plugins = {
        kwin4_effect_geometry_changeEnabled = true;
      };
    })

    (mkIf cfg.scripts.squash.enable {
      home.file = {
        ".local/share/kwin/effects/kwin4_effect_squash2" = {
          source = "${pkgs.kwin-scripts.squash2}/share/kwin/effects/kwin4_effect_squash2";
          recursive = true;
        };
      };

      programs.plasma.configFile.kwinrc.Plugins = {
        kwin4_effect_squash2Enabled = true;
      };
    })

    (mkIf cfg.scripts.kzone.enable {
      home.file = {
        ".local/share/kwin/scripts/kzones" = {
          source = "${pkgs.kdePackages.kzones}/share/kwin/scripts/kzones";
          recursive = true;
        };
      };

      programs.plasma.configFile.kwinrc.Plugins = {
        kzonesEnabled = true;
      };
    })
  ];
}