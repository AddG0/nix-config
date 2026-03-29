{inputs, config, ...}: {
  imports = [inputs.nitrox-nix.nixosModules.default];
  services.nitrox-server = {
    enable = true;
    openFirewall = true;
    subnauticaPath = "/home/${config.hostSpec.username}/.local/share/Steam/steamapps/common/Subnautica";
  };
}
