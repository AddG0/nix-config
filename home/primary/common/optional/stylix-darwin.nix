{
  inputs,
  pkgs,
  ...
}: {
  stylix = {
    enable = true;
    image = "${pkgs.kdePackages.plasma-workspace-wallpapers}/share/wallpapers/Nexus/contents/images_dark/5120x2880.png";
    base16Scheme = "${inputs.tt-schemes}/base16/catppuccin-mocha.yaml";
    fonts = {
      sansSerif = {
        package = pkgs.roboto;
        name = "Roboto";
      };
      serif = {
        package = pkgs.roboto;
        name = "Roboto";
      };
      monospace = {
        package = pkgs.nerd-fonts.roboto-mono;
        name = "RobotoMono Nerd Font";
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
    opacity = {
      applications = 1.0;
      terminal = 1.0;
      desktop = 1.0;
      popups = 1.0;
    };
    polarity = "dark";
  };
}
