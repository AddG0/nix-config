{
  hostName,
  networking,
  config,
  ...
}: let
  inherit (networking) defaultGateway nameservers;
  inherit (networking.hostsAddr.${hostName}) iface ipv4;
  ipv4WithMask = "${ipv4}/24";
in {
  # supported file systems, so we can mount any removable disks with these filesystems
  boot.supportedFilesystems = [
    "ext4"
    "btrfs"
    "xfs"
    "fat"
    "vfat"
    "exfat"
  ];

  networking = {inherit hostName;};
  networking.useNetworkd = true;
  systemd.network.enable = true;

  # Add ipv4 address to the bridge.
  systemd.network.networks."10-${iface}" = {
    matchConfig.Name = [iface];
    networkConfig = {
      Address = [ipv4WithMask];
      Gateway = defaultGateway;
      DNS = nameservers;
      IPv6AcceptRA = true;
    };
    linkConfig.RequiredForOnline = "routable";
  };
}
