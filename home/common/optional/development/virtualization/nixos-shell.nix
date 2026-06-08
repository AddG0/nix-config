{
  inputs,
  pkgs,
  ...
}: {
  home.packages = [
    inputs.nixos-shell.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];
}
