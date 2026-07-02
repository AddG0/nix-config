{pkgs, ...}: {
  services.automatic-timezoned.enable = true;

  # The "+" prefix runs ExecStartPost with full privileges, bypassing the
  # service's `User=automatic-timezoned`. Without it, `systemctl set-environment`
  # fails with "Access denied as the requested operation requires interactive
  # authentication" and the per-user dbus updates can't escalate either.
  systemd.services.automatic-timezoned.serviceConfig.ExecStartPost = "+${pkgs.writeShellScript "update-tz-env" ''
    set -u
    [ -L /etc/localtime ] || exit 0
    TZ=$(${pkgs.coreutils}/bin/readlink -f /etc/localtime | ${pkgs.gnugrep}/bin/grep -oP '(?<=zoneinfo/).*' || echo "UTC")

    # System-wide env for future system services
    ${pkgs.systemd}/bin/systemctl set-environment TZ="$TZ"

    # Per active user session: push TZ into the dbus activation env + user
    # systemd manager (affects newly-spawned user services/apps), then drop
    # a marker file that a user-level path unit can watch to restart already-
    # running graphical apps that captured the old TZ at launch.
    for user_runtime in /run/user/*; do
      [ -d "$user_runtime" ] || continue
      uid=$(${pkgs.coreutils}/bin/basename "$user_runtime")
      user=$(${pkgs.getent}/bin/getent passwd "$uid" | ${pkgs.coreutils}/bin/cut -d: -f1) || continue
      [ -n "$user" ] || continue

      XDG_RUNTIME_DIR="$user_runtime" \
      DBUS_SESSION_BUS_ADDRESS="unix:path=$user_runtime/bus" \
        ${pkgs.util-linux}/bin/runuser -u "$user" -- \
        ${pkgs.dbus}/bin/dbus-update-activation-environment --systemd TZ="$TZ" 2>/dev/null || true

      ${pkgs.coreutils}/bin/install -o "$uid" -g "$uid" -m 644 /dev/null "$user_runtime/tz-changed" || true
    done
  ''}";

  # NetworkManager dispatcher: re-run timezone detection when any non-loopback
  # interface comes up, so reconnecting to wifi in a new region updates TZ.
  networking.networkmanager.dispatcherScripts = [
    {
      source = pkgs.writeText "update-timezone" ''
        #!/bin/sh
        if [ "$2" = "up" ] && [ "$DEVICE_IFACE" != "lo" ]; then
          ${pkgs.systemd}/bin/systemctl restart automatic-timezoned.service
        fi
      '';
      type = "basic";
    }
  ];

  # New login shells get TZ from /etc/localtime — covers SSH/tty sessions
  # opened after a timezone change without going through the systemd dance.
  environment.loginShellInit = ''
    if [ -L /etc/localtime ]; then
      export TZ=$(readlink -f /etc/localtime | grep -oP '(?<=zoneinfo/).*' || echo "UTC")
    fi
  '';
}
