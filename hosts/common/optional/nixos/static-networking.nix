# Assign this host's address from nix-secrets instead of leasing it over DHCP.
{config, ...}: let
  inherit (config.hostSpec.networking) hostsAddr hostsInterface;
  host = config.hostSpec.hostName;
  addr = hostsAddr.${host};
in {
  assertions = [
    {
      assertion = addr ? iface && addr ? gateway && addr ? nameservers;
      message = "static-networking: networking.hostsAddr.${host} in nix-secrets needs iface, gateway and nameservers";
    }
    {
      assertion = !config.networking.networkmanager.enable;
      message = "static-networking: ${host} also enables NetworkManager, which assigns addresses from its own profiles; drop networking.networkmanager.enable";
    }
  ];

  networking = {
    useDHCP = false;
    inherit (hostsInterface.${host}) interfaces;
    inherit (addr) nameservers;
    defaultGateway = addr.gateway;
  };
}
