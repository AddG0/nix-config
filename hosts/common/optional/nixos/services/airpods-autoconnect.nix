{pkgs, ...}: let
  # AirPods MAC. Hardcoded because this is opt-in per-host via imports,
  # and only freya currently has paired AirPods.
  airpodsMac = "98:1C:A2:DF:A1:A2";

  # Backoff between reconnect attempts (seconds). Bounded: after the last one we
  # go idle and wait for the next disconnect edge — we never busy-loop.
  backoffs = "2 4 8 16 32 64";

  # Wait this long for BlueZ to actually finish a Connect() before treating the
  # attempt as done. Must exceed BlueZ's internal page timeout: a premature
  # D-Bus reply timeout returns while BlueZ is still connecting underneath, so
  # the next attempt collides with it as br-connection-busy (the old storm).
  connectTimeout = "45";

  airpods-autoconnect = pkgs.writeShellApplication {
    name = "airpods-autoconnect";
    # busctl ships with systemd; dbus-monitor with pkgs.dbus; gawk parses the
    # multi-line signal. We talk to BlueZ directly over D-Bus — bluetoothctl is
    # unreliable without a TTY (exits before issuing Connect).
    runtimeInputs = with pkgs; [dbus systemd coreutils gnugrep gawk];
    text = ''
      set -uo pipefail

      MAC="${airpodsMac}"
      DEV_PATH="/org/bluez/hci0/dev_$(echo "$MAC" | tr ':' '_')"
      BACKOFFS=(${backoffs})
      CONNECT_TIMEOUT=${connectTimeout}

      log() { echo "[airpods-autoconnect] $*"; }

      is_connected() {
        # Returns "b true" or "b false" — match the exact reply line.
        busctl --system get-property org.bluez "$DEV_PATH" \
          org.bluez.Device1 Connected 2>/dev/null \
          | grep -qx "b true"
      }

      # One reconnect sequence. Single-flight by construction: the edge loop runs
      # this inline, so a new sequence can't begin until it returns, and only a
      # genuine Connected->false edge starts one.
      reconnect() {
        local delay err
        for delay in "''${BACKOFFS[@]}"; do
          is_connected && { log "connected; done"; return 0; }
          log "waiting ''${delay}s"
          sleep "$delay"
          is_connected && { log "connected during backoff; done"; return 0; }

          # --timeout makes busctl wait for BlueZ's real result instead of
          # returning early and orphaning an in-flight attempt. We never fire a
          # second Connect() until this one returns, so we can't race ourselves.
          log "Connect() (up to ''${CONNECT_TIMEOUT}s)"
          if err=$(busctl --system --timeout="$CONNECT_TIMEOUT" call org.bluez \
                    "$DEV_PATH" org.bluez.Device1 Connect 2>&1); then
            log "reconnected"
            return 0
          fi
          case "$err" in
            *br-connection-busy*|*"in progress"*)
              log "attempt already in progress (likely BlueZ policy); backing off" ;;
            *) log "Connect() failed: $err" ;;
          esac
        done
        log "giving up; idle until next disconnect"
        return 1
      }

      log "watching $DEV_PATH for Connected edges"

      # dbus-monitor emits multi-line PropertiesChanged signals; gawk collapses
      # each to a single token only when the Connected property actually flips.
      # Edge-triggered on purpose: our own Connect() traffic and RSSI churn no
      # longer re-trigger us (the level-triggered original re-fired off its own
      # signals, stacking overlapping reconnect loops).
      dbus-monitor --system \
        "type='signal',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='$DEV_PATH'" \
        | gawk '
            /string "Connected"/           { seen = 1; next }
            seen && /boolean (true|false)/ {
              print (/true/ ? "CONNECTED" : "DISCONNECTED"); fflush(); seen = 0; next
            }
            { seen = 0 }
          ' \
        | while IFS= read -r edge; do
            case "$edge" in
              CONNECTED)    log "AirPods connected" ;;
              DISCONNECTED) log "AirPods disconnected"; reconnect || true ;;
            esac
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
