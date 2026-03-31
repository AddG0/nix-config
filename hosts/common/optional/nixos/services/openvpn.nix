{
  config,
  inputs,
  pkgs,
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

  # Split DNS: only addg0.com queries go through the VPN to the home DNS server
  services.resolved.enable = true;

  services.openvpn.servers.homeVPN = {
    autoStart = true;
    updateResolvConf = false;
    config = ''
      config ${config.sops.secrets."openvpn-home-config".path}
      auth-user-pass ${config.sops.secrets."openvpn-home-auth".path}
      script-security 2
      up ${pkgs.writeShellScript "vpn-up" ''
        ${pkgs.systemd}/bin/resolvectl dns tun0 192.168.1.1
        ${pkgs.systemd}/bin/resolvectl domain tun0 ~${config.hostSpec.domain}
      ''}
      down ${pkgs.writeShellScript "vpn-down" ''
        ${pkgs.systemd}/bin/resolvectl revert tun0
      ''}
    '';
  };

  networking.firewall.trustedInterfaces = ["tun0"];
}
