{
  inputs,
  pkgs,
  ...
}: {
  home.packages = [
    inputs.nixos-shell.packages.${pkgs.system}.default
  ];
}
