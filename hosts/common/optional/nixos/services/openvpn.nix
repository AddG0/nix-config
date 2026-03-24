{
  config,
  inputs,
  ...
}: {
  sops.secrets."openvpn-home-config" = {
    sopsFile = "${inputs.nix-secrets}/users/${config.hostSpec.username}/vpn/home/home.ovpn.enc";
    format = "binary";
    owner = "root";
    mode = "0400";
  };

  sops.secrets."openvpn-home-auth" = {
    sopsFile = "${inputs.nix-secrets}/users/${config.hostSpec.username}/vpn/home/auth.enc";
    format = "binary";
    owner = "root";
    mode = "0400";
  };

  services.openvpn.servers.homeVPN = {
    autoStart = true;
    updateResolvConf = false;
    config = ''
      config ${config.sops.secrets."openvpn-home-config".path}
      auth-user-pass ${config.sops.secrets."openvpn-home-auth".path}
    '';
  };

  networking.firewall.trustedInterfaces = ["tun0"];
}
