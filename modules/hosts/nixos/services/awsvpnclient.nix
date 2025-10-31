{
  lib,
  config,
  pkgs,
  ...
}:
with lib; let
  cfg = config.programs.awsvpnclient;
in {
  options.programs.awsvpnclient = {
    enable = mkEnableOption "Enable AWS VPN Client";
  };

  config = mkIf cfg.enable {
    # Mark openssl-1.1.1w as allowed since AWS VPN Client requires it
    nixpkgs.config.permittedInsecurePackages = [
      "openssl-1.1.1w"
    ];

    environment.systemPackages = [pkgs.awsvpnclient];
    systemd.packages = [pkgs.awsvpnclient];

    # Even though the service already defines this, nixos doesn't pick that up and leaves the service disabled
    systemd.services.AwsVpnClientService.wantedBy = ["multi-user.target"];

    # Required for DNS resolution in AWS VPN Client
    services.resolved.enable = true;
  };
}
