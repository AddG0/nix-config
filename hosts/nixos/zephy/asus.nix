{
  pkgs,
  lib,
  ...
}: {
  systemd.user.services."asus-keyboard-light" = {
    description = "Set ASUS keyboard lights at startup";
    wantedBy = ["default.target"];
    serviceConfig = {
      ExecStart = "${pkgs.asusctl}/bin/asusctl -k high && ${pkgs.asusctl}/bin/asusctl aura rainbow-wave";
    };
  };

  services = {
    asusd = {
      enable = lib.mkDefault true;
      enableUserService = true;
    };

    supergfxd = {
      enable = true;
    };

    asus-numberpad-driver = {
      enable = true;
      layout = "gx551"; # Layout for Zephyrus Duo models
    };
  };
}
