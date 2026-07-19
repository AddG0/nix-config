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
    # btmon (pkgs.bluez) supplies the disconnect reason; busctl (systemd) does
    # the Connect()/state checks. Not bluetoothctl — unreliable without a TTY
    # (exits before issuing Connect).
    runtimeInputs = with pkgs; [bluez systemd coreutils gnugrep gawk];
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

      # One reconnect sequence. Single-flight by construction: the reason loop
      # runs this inline, so a new sequence can't begin until it returns, and
      # only a 0x14 low-resources event starts one.
      reconnect() {
        local delay err
        # btmon sees the disconnect before bluetoothd flips Device1.Connected;
        # settle so the first is_connected() doesn't read a stale "true".
        sleep 1
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
        log "giving up; idle until next low-resources drop"
        return 1
      }

      log "watching HCI for AirPods ($MAC) low-resources disconnects"

      # Reconnect ONLY on HCI reason 0x14 (Remote Device Terminated due to Low
      # Resources) — the spurious drop. Every other reason is intentional and
      # must NOT be fought, or we steal the AirPods from wherever they went:
      #   0x13 / 0x16 — handoff to phone or another host
      #   0x15        — powered off / back in the case
      #
      # Disconnect Complete carries only a connection handle, not an address, so
      # we tag the AirPods' handle from whichever connection event carries their
      # address (BR/EDR "Address:" or LE "Peer address:") and match the
      # disconnect on it. Caveat: if this service (re)starts while they're
      # already connected we miss that event and can miss the next drop until
      # they reconnect once — a safe failure (we under-reconnect, never steal).
      stdbuf -oL btmon 2>/dev/null \
        | gawk -v mac="$MAC" '
            # New packet resets the block handle; flag Disconnect Complete blocks.
            /^[<>=@]/ { in_disc = ($0 ~ /Disconnect Complete/); h = ""; next }

            $1 == "Handle:"                  { h = $2; next }
            /[Aa]ddress:/ && index($0, mac)  { airpods[h] = 1; next }
            in_disc && $1 == "Reason:" && (h in airpods) {
              code = $0; sub(/.*\(/, "", code); sub(/\).*/, "", code)
              print code; fflush()
              delete airpods[h]
              next
            }
          ' \
        | while IFS= read -r reason; do
            if [ "$reason" = "0x14" ]; then
              log "AirPods low-resources drop ($reason); reconnecting"
              reconnect || true
            else
              log "AirPods disconnect reason $reason; leaving them (handoff/idle/case)"
            fi
          done
    '';
  };
in {
  # BlueZ's Policy.ReconnectAttempts (services/bluetooth.nix) only fires on link
  # loss (supervision timeout), never on remote-initiated disconnects — so the
  # AirPods' spurious 0x14 low-resources drop is never auto-recovered. This
  # service fills that gap; see the script for why only 0x14 and not every drop.
  systemd.services.airpods-autoconnect = {
    description = "Reconnect AirPods after low-resources drops BlueZ ignores";
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
