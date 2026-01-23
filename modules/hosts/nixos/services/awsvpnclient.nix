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

    systemd.services.awsvpnclient = {
      description = "AWS VPN Client Service";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];

      serviceConfig = {
        Type = "simple";
        ExecStart = "${pkgs.awsvpnclient-service}/bin/awsvpnclient-service";
        Restart = "always";
        RestartSec = "1s";
      };
    };

    # Required for DNS resolution in AWS VPN Client
    services.resolved.enable = true;
  };
}
