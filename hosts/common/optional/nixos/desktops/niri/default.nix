{
  inputs,
  lib,
  ...
}: {
  imports = [
    inputs.niri.nixosModules.niri
  ];

  programs.niri.enable = true;

  # Lower priority than Plasma's mkDefault (1000) so Plasma wins when both are enabled
  services.greetd.sessionCommand = lib.mkOverride 1500 "niri-session";
}
