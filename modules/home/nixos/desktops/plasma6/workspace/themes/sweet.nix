{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.plasma.workspace.themes.sweet;
in {
  options.programs.plasma.workspace.themes.sweet = {
    enable = mkEnableOption "Sweet KDE theme";

    useAuroraeDecoration = mkOption {
      type = types.bool;
      default = true;
      description = "Whether to use Sweet Aurorae window decoration";
    };
  };

  config = mkIf cfg.enable {
    programs.plasma = {
      workspace = {
        # Set the Sweet color scheme
        colorScheme = mkDefault "Sweet";

        # Set the Sweet plasma theme
        theme = mkDefault "Sweet";

        # Window decorations - use Aurorae if enabled, otherwise use Breeze
        windowDecorations = mkIf cfg.useAuroraeDecoration (mkDefault {
          library = "org.kde.kwin.aurorae";
          theme = "__aurorae__svg__Sweet";
        });
      };
    };

    # Symlink theme files to where KDE expects them
    xdg.dataFile = {
      # Color scheme
      "color-schemes/Sweet.colors".source = "${pkgs.themes.plasma.sweet-kde}/share/color-schemes/Sweet.colors";

      # Desktop theme (Plasma theme)
      "plasma/desktoptheme/Sweet".source = "${pkgs.themes.plasma.sweet-kde}/share/plasma/desktoptheme/Sweet";

      # Aurorae window decoration
      "aurorae/themes/Sweet".source = mkIf cfg.useAuroraeDecoration "${pkgs.themes.plasma.sweet-aurorae}/share/aurorae/themes/Sweet";
    };
  };
}
