{
  config,
  inputs,
  ...
}: {
  sops.secrets."openvpn-home-config" = {
    sopsFile = "${inputs.nix-secrets}/secrets/openvpn/homeVPN.conf";
    format = "binary";
    owner = "root";
    mode = "0400";
  };

  services.openvpn.servers.homeVPN = {
    autoStart = true;
    updateResolvConf = false;
    config = ''config ${config.sops.secrets."openvpn-home-config".path}'';
  };

  networking.firewall.trustedInterfaces = ["tun0"];
}
