{
  pkgs,
  lib,
  ...
}: {
  programs.rofi = {
    enable = true;
    package = pkgs.rofi-wayland;
    terminal = "${pkgs.ghostty}/bin/ghostty";
    theme = lib.mkForce "${pkgs.rofi-presets}/share/rofi-presets/launchers/type-7/style-2.rasi";
    extraConfig = {
      show-icons = true;
      # icon-theme = "";
      # hover-select = true;
      drun-match-fields = "name";
      drun-display-format = "{name}";
      #FIXME not working
      drun-search-paths = "/home/addg/.nix-profile/share/applciations,/home/addg/.nix-profile/share/wayland-sessions";
    };
  };

  home.file.".config/rofi/images" = {
    source = "${pkgs.rofi-presets}/share/rofi-presets/images";
    recursive = true;
  };
}
