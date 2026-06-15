{
  pkgs,
  lib,
  ...
}: {
  # On Darwin, Postman is managed via homebrew cask for stable path (avoids
  # SMAppService re-registration popups on every nix store path change)
  home.packages = lib.optionals pkgs.stdenv.isLinux [pkgs.postman];
}
