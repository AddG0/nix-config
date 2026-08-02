{inputs, ...}: {
  imports = [
    inputs.niri.nixosModules.niri
  ];

  programs.niri.enable = true;

  services.greetd.desktops.niri = "niri-session";
}
