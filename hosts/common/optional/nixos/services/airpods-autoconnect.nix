{pkgs, ...}: let
  # AirPods MAC. Hardcoded because this is opt-in per-host via imports,
  # and only freya currently has paired AirPods.
  airpodsMac = "98:1C:A2:DF:A1:A2";

  # Backoff intervals between Connect() attempts (seconds). First attempt is
  # delayed by 2s so we don't fight a same-moment spontaneous reconnect.
  backoffs = "2 4 8 16 32 64";

  airpods-autoconnect = pkgs.writeShellApplication {
    name = "airpods-autoconnect";
    # busctl ships with systemd; dbus-monitor with pkgs.dbus.
    # We talk to BlueZ directly over D-Bus — bluetoothctl is unreliable
    # without a TTY (registers as a client and exits before issuing Connect).
    runtimeInputs = with pkgs; [dbus systemd coreutils gnugrep];
    text = ''
      set -uo pipefail

      MAC="${airpodsMac}"
      DEV_PATH="/org/bluez/hci0/dev_$(echo "$MAC" | tr ':' '_')"
      BACKOFFS=(${backoffs})

      log() { echo "[airpods-autoconnect] $*"; }

      is_connected() {
        # Returns "b true" or "b false" — match the exact reply line.
        busctl --system get-property org.bluez "$DEV_PATH" \
          org.bluez.Device1 Connected 2>/dev/null \
          | grep -qx "b true"
      }

      attempt_reconnect() {
        for delay in "''${BACKOFFS[@]}"; do
          if is_connected; then
            log "already connected, stopping retry loop"
            return 0
          fi
          log "waiting ''${delay}s before next reconnect attempt"
          sleep "$delay"
          log "calling org.bluez.Device1.Connect()"
          if err=$(busctl --system call org.bluez "$DEV_PATH" \
                    org.bluez.Device1 Connect 2>&1); then
            log "reconnected"
            return 0
          else
            log "Connect() failed: $err"
          fi
        done
        log "giving up after all backoff attempts"
        return 1
      }

      log "watching $DEV_PATH for disconnects"

      # Filter dbus-monitor to PropertiesChanged on the AirPods device path only.
      # The bus is idle while connected and idle while disconnected — we wake
      # only when this specific device's properties actually change. We don't
      # parse the structured signal output; any wake-up just triggers a state
      # check via busctl get-property, which is simpler and harder to get wrong.
      dbus-monitor --system \
        "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='$DEV_PATH'" \
        | while IFS= read -r _line; do
            if ! is_connected; then
              log "AirPods disconnected, starting reconnect loop"
              attempt_reconnect || true
            fi
          done
    '';
  };
in {
  # Works around BlueZ ignoring AirPods' graceful disconnect (HCI Reason 0x14).
  # The Policy.ReconnectAttempts in services/bluetooth.nix only fires on link
  # loss (supervision timeout) — not on remote-initiated disconnects, which is
  # what AirPods send when handing off to another device or going idle.
  systemd.services.airpods-autoconnect = {
    description = "Reconnect AirPods after graceful disconnects BlueZ ignores";
    after = ["bluetooth.target"];
    wants = ["bluetooth.target"];
    wantedBy = ["multi-user.target"];

    serviceConfig = {
      Type = "simple";
      Restart = "always";
      RestartSec = 5;
      ExecStart = "${airpods-autoconnect}/bin/airpods-autoconnect";

      # Runs as root to talk to BlueZ on the system bus without needing a
      # polkit rule (bluez doesn't create a privileged group on NixOS).
      ProtectSystem = "strict";
      ProtectHome = true;
      ProtectKernelTunables = true;
      ProtectKernelModules = true;
      ProtectControlGroups = true;
      PrivateTmp = true;
      RestrictSUIDSGID = true;
    };
  };
}
