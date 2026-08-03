{
  lib,
  pkgs,
  osConfig,
  ...
}: let
  cameras = osConfig.services.obsbot-camera.cameras or {};
  # No cameras on this host → no systemd unit and no shell app in the closure.
  hasObsbot = (osConfig.services.obsbot-camera.enable or false) && cameras != {};

  # Share the host module's discovery so both watch the same nodes.
  listNodes = osConfig.services.obsbot-camera.listNodesScript;

  guard = (import ./mk-guard.nix {inherit lib pkgs;}).mkGuard {
    name = "obsbot";
    description = "Disable Safe Eyes while an Obsbot camera is in use";
    runtimeInputs = with pkgs; [inotify-tools psmisc];

    conditionFn = ''
      # Re-read each time rather than snapshotting, so replug is picked up.
      obsbot_nodes() {
        ${listNodes} | cut -d' ' -f2
      }

      condition_active() {
        local device
        while read -r device; do
          if fuser "$device" >/dev/null 2>&1; then
            return 0
          fi
        done < <(obsbot_nodes)
        return 1
      }
    '';

    # The outer loop handles unplug/replug — if all nodes disappear, poll until
    # they come back.
    eventLoop = ''
      # Handle a device that's already in use at service start.
      reconcile

      while true; do
        mapfile -t existing < <(obsbot_nodes)

        if [ "''${#existing[@]}" -eq 0 ]; then
          # Configured Obsbot devices aren't present (unplugged). Drop any
          # stale flag and poll for the device appearing.
          mark_inactive
          sleep 30
          continue
        fi

        # Rapid open→close probes (permission/preview checks) would fire a
        # fuser + safeeyes reconcile each; coalesce them into one.
        coalesce_reconcile 1 5 < <(inotifywait -q -m -e open -e close "''${existing[@]}" 2>/dev/null || true)

        # inotifywait exited (typically a watched path was removed). Re-check
        # before looping so safeeyes state is correct during the gap.
        reconcile
        sleep 2
      done
    '';
  };
in
  lib.mkIf hasObsbot guard
