{
  lib,
  callPackage,
  ...
}: {
  ghostty = callPackage ./ghostty/package.nix {};
  waybar = callPackage ./waybar/package.nix {};
  tmux = callPackage ./tmux/package.nix {};
}
