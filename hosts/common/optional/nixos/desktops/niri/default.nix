{
  inputs,
  pkgs,
  ...
}: {
  imports = [
    inputs.niri.nixosModules.niri
  ];

  programs.niri.enable = true;
  # FLAKE-UPDATE: drop once niri-flake's niri-stable builds against our nixpkgs;
  # its 2026-08-04 pin still asks for the removed libdisplay-info_0_2.
  programs.niri.package = pkgs.niri;

  services.greetd.desktops.niri = "niri-session";
}
