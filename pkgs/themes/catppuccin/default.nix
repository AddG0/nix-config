# Catppuccin theme packages
pkgs: {
  bat = pkgs.callPackage ./bat {};
  ghostty = pkgs.callPackage ./ghostty {};
  hyprland = pkgs.callPackage ./hyprland {};
  k9s = pkgs.callPackage ./k9s {};
  nushell = pkgs.callPackage ./nushell {};
  obsidian = pkgs.callPackage ./obsidian {};
  process-compose = pkgs.callPackage ./process-compose {};
  tmux = pkgs.callPackage ./tmux {};
  waybar = pkgs.callPackage ./waybar {};
  yazi = pkgs.callPackage ./yazi {};
}
