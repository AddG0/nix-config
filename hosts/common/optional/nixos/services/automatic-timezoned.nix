{ pkgs, ... }:
{
  # Enable IP-based automatic timezone detection
  # services.ip-timezone.enable = true;

  services.automatic-timezoned.enable = true;

  # Update system TZ environment variable after timezone changes
  systemd.services.automatic-timezoned.serviceConfig.ExecStartPost = pkgs.writeShellScript "update-tz-env" ''
    # Extract timezone from /etc/localtime symlink
    if [ -L /etc/localtime ]; then
      TZ=$(${pkgs.coreutils}/bin/readlink -f /etc/localtime | ${pkgs.gnugrep}/bin/grep -oP '(?<=zoneinfo/).*' || echo "UTC")
      # Update systemd environment for services
      ${pkgs.systemd}/bin/systemctl set-environment TZ="$TZ"
      # Update user session environments for running graphical sessions
      for user_runtime in /run/user/*; do
        if [ -d "$user_runtime" ]; then
          uid=$(${pkgs.coreutils}/bin/basename "$user_runtime")
          sudo -u "#$uid" DBUS_SESSION_BUS_ADDRESS="unix:path=$user_runtime/bus" \
            ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd TZ="$TZ" 2>/dev/null || true
        fi
      done
    fi
  '';

  # Trigger timezone update when WiFi connects
  # NetworkManager dispatcher runs scripts when network connections change
  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeText "update-timezone" ''
        #!/bin/sh
        # Only run on WiFi up events
        if [ "$2" = "up" ] && [ "$DEVICE_IFACE" != "lo" ]; then
          ${pkgs.systemd}/bin/systemctl restart automatic-timezoned.service
        fi
      '';
      type = "basic";
    }
  ];

  # Set TZ environment variable from /etc/localtime for browsers
  # automatic-timezoned only updates /etc/localtime symlink, not the TZ env var
  # Browsers need an explicit timezone name (e.g., "Australia/Perth") in TZ variable
  # The syntax TZ=:/etc/localtime doesn't work due to Chromium bug:
  # https://bugs.chromium.org/p/chromium/issues/detail?id=811403
  # This script extracts the actual timezone name from the symlink at login
  environment.loginShellInit = ''
    if [ -L /etc/localtime ]; then
      export TZ=$(readlink -f /etc/localtime | grep -oP '(?<=zoneinfo/).*' || echo "UTC")
    fi
  '';
}
