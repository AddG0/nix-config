{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.ip-timezone;
in {
  options.services.ip-timezone = {
    enable = mkEnableOption "IP-based automatic timezone detection";

    interval = mkOption {
      type = types.str;
      default = "30min";
      description = "How often to check and update the timezone";
    };

    provider = mkOption {
      type = types.str;
      default = "https://ipapi.co/timezone";
      description = "The IP geolocation API endpoint to use for timezone detection";
    };
  };

  config = mkIf cfg.enable {
    # Disable the broken automatic-timezoned that relies on geoclue2
    services.automatic-timezoned.enable = mkForce false;

    # Create a working IP-based timezone detection service
    systemd.services.ip-timezone = {
      description = "Update timezone based on IP geolocation";
      serviceConfig = {
        Type = "oneshot";
        ExecStart = pkgs.writeShellScript "update-timezone" ''
          set -euo pipefail

          # Get timezone from IP geolocation
          TIMEZONE=$(${pkgs.curl}/bin/curl -s ${cfg.provider} || echo "")

          if [ -z "$TIMEZONE" ]; then
            echo "Failed to get timezone from IP geolocation API"
            exit 1
          fi

          # Validate timezone by checking if timedatectl accepts it
          if ! ${pkgs.systemd}/bin/timedatectl list-timezones | ${pkgs.gnugrep}/bin/grep -qx "$TIMEZONE"; then
            echo "Invalid timezone returned: $TIMEZONE"
            exit 1
          fi

          # Get current timezone
          CURRENT_TZ=$(readlink -f /etc/localtime 2>/dev/null | ${pkgs.gnugrep}/bin/grep -oP '(?<=zoneinfo/).*' || echo "")

          if [ "$TIMEZONE" != "$CURRENT_TZ" ]; then
            echo "Updating timezone from $CURRENT_TZ to $TIMEZONE"
            ${pkgs.systemd}/bin/timedatectl set-timezone "$TIMEZONE"
          else
            echo "Timezone already set to $TIMEZONE"
          fi
        '';
      };
    };

    # Run the timezone update service periodically
    systemd.timers.ip-timezone = {
      description = "Periodically update timezone based on location";
      wantedBy = ["timers.target"];
      timerConfig = {
        OnBootSec = "1min";
        OnUnitActiveSec = cfg.interval;
        Unit = "ip-timezone.service";
      };
    };
  };
}
