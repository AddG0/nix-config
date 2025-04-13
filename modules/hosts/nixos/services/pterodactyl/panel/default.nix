{
  config,
  pkgs,
  lib,
  ...
}: {
  imports = [
    ./options.nix
    ./config.nix
    ./blueprint.nix
  ];
}
