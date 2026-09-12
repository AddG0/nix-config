# AWS VPN Client: privileged daemon only. The GUI is installed per-user by
# home/common/optional/awsvpnclient.nix, where the stylix palette lives.
{inputs, ...}: {
  imports = [inputs.awsvpnclient-nix.nixosModules.default];

  services.awsvpnclient = {
    enable = true;
    installGui = false;
  };
}
