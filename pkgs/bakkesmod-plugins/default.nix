# BakkesMod plugin packages
pkgs: let
  mkBakkesModPlugin = pkgs.callPackage ./mk-bakkesmod-plugin.nix {};
in {
  ingamerank = mkBakkesModPlugin (import ./ingamerank);
}
