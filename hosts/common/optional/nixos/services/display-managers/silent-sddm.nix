# SDDM with the SilentSDDM theme, as a host's login manager in place of greetd.
{
  inputs,
  config,
  lib,
  ...
}: {
  imports = [inputs.silent-sddm.nixosModules.default];

  assertions = [
    {
      assertion = !config.services.greetd.enable;
      message = "silent-sddm: greetd is enabled too, and both would claim the display; drop the greetd import on this host.";
    }
  ];

  programs.silentSDDM = {
    enable = true;
    theme = lib.mkDefault "catppuccin-${config.desktops.catppuccin.flavor}";
  };
}
