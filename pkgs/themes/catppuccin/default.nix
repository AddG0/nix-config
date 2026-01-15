# Catppuccin theme packages
pkgs: {
  ghostty = pkgs.callPackage ./ghostty {};
  nushell = pkgs.callPackage ./nushell {};
  process-compose = pkgs.callPackage ./process-compose {};
  tmux = pkgs.callPackage ./tmux {};
  waybar = pkgs.callPackage ./waybar {};
}
