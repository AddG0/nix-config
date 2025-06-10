{
  lib,
  callPackage,
  ...
}: {
  ghostty = callPackage ./ghostty/package.nix {};
  tmux = callPackage ./tmux/package.nix {};
  waybar = callPackage ./waybar/package.nix {};
}
