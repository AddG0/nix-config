{
  pkgs,
  inputs,
  ...
}: {
  # macOS-leaning theme. Stylix is the top-level theming engine — all visual
  # values (colors, fonts, opacities, cursor) live here so every stylix-aware
  # app (noctalia, KDE, GTK, terminals, etc.) inherits a consistent look.
  #
  # Key rationale per category:
  #   - Inter is the de-facto free substitute for Apple's SF Pro.
  #   - Catppuccin Mocha is the closest base16 scheme to macOS dark mode.
  #   - Opacities <1.0 enable the compositor's frosted-glass blur to show
  #     through panels/popups/desktop surfaces.
  stylix = {
    enable = true;
    image = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Nexus/contents/images_dark/5120x2880.png";
    base16Scheme = "${inputs.tt-schemes}/base16/catppuccin-mocha.yaml";
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Modern-Classic";
      size = 24;
    };
    fonts = {
      sansSerif = {
        package = pkgs.inter;
        name = "Inter";
      };
      serif = {
        package = pkgs.inter;
        name = "Inter";
      };
      monospace = {
        package = pkgs.nerd-fonts.meslo-lg;
        name = "MesloLGS Nerd Font";
      };
      emoji = {
        package = pkgs.noto-fonts-color-emoji;
        name = "Noto Color Emoji";
      };
      sizes = {
        applications = 11;
        terminal = 12;
        desktop = 11;
        popups = 12;
      };
    };
    # Apps stay opaque (blur comes from the compositor below them). Terminal
    # gets subtle transparency. Desktop surfaces (bar/dock/panels) stay
    # opaque because noctalia uses `auto_hide` with no exclusion zone — a
    # transparent bar over content reads as visual noise. Popups are also kept
    # opaque so notifications/OSDs read cleanly over busy content.
    opacity = {
      applications = 1.0;
      terminal = 0.95;
      desktop = 1.0;
      popups = 1.0; # menus, OSDs, notifications
    };
    polarity = "dark";
    icons = {
      enable = true;
      package = pkgs.papirus-icon-theme;
      dark = "Papirus-Dark";
      light = "Papirus-Light";
    };
  };
}
