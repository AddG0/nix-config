# The sesh tmuxinator shim against the real tmuxinator, over the same project trees.
{
  harness,
  pkgs,
  ...
}: let
  shim = pkgs.callPackage ../tmuxinator-shim.nix {};
in
  harness.bats "sesh-tmuxinator-shim" [./tmuxinator-shim.bats] {
    nativeBuildInputs = [pkgs.coreutils pkgs.diffutils];
    shim = "${shim}/bin/tmuxinator";
    real = "${pkgs.tmuxinator}/bin/tmuxinator";
  }
