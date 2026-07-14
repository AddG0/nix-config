# FLAKE-UPDATE: drop once nixpkgs ships a working spicetify-cli. The current one
# has breaking Linux changes (spicetify/cli#3888, spicetify-nix#374) that blank
# Spotify's UI after login; pin the patcher to last-good nixpkgs 67650575
# (spicetify-cli 2.43.2) to fix it. Re-check after `nix flake update`.
# CHECK-RUNTIME: runtime blank screen, not a build failure — verify Spotify's UI renders after login.
_: _final: prev: {
  inherit
    (import (builtins.fetchTarball {
      url = "https://github.com/NixOS/nixpkgs/archive/67650575de1a9c27262b96b2608f7d41ae311a0b.tar.gz";
      sha256 = "00c729p8gqka57hbvsx09rxmbzc3g05pxgv0vgg5h0jcnghap3sr";
    }) {inherit (prev.stdenv.hostPlatform) system;})
    spicetify-cli
    ;
}
