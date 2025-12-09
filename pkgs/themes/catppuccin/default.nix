# Catppuccin theme packages
pkgs: {
  ghostty = pkgs.callPackage ./ghostty {};
  nushell = pkgs.callPackage ./nushell {};
  tmux = pkgs.callPackage ./tmux {};
  waybar = pkgs.callPackage ./waybar {};
}
