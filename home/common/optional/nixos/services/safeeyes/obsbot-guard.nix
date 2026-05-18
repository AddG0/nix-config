{
  lib,
  pkgs,
  osConfig,
  ...
}: let
  # Derive watched device paths from the host's services.obsbot-camera config
  # (single source of truth). If no Obsbot cameras are configured on this host,
  # the guard becomes a no-op — no systemd unit, no shell app in the closure.
  cameras = osConfig.services.obsbot-camera.cameras or {};
  obsbotDevices = lib.unique (lib.concatLists (lib.mapAttrsToList (_: c: c.triggerPaths) cameras));
  hasObsbot = obsbotDevices != [];

  obsbotDeviceLines = lib.concatMapStringsSep "\n      " lib.escapeShellArg obsbotDevices;

  guard = (import ./mk-guard.nix {inherit lib pkgs;}).mkGuard {
    name = "obsbot";
    description = "Disable Safe Eyes while an Obsbot camera is in use";
    runtimeInputs = with pkgs; [inotify-tools psmisc];

    conditionFn = ''
      obsbot_devices=(
        ${obsbotDeviceLines}
      )

      condition_active() {
        local device
        for device in "''${obsbot_devices[@]}"; do
          if [ -e "$device" ] && fuser "$device" >/dev/null 2>&1; then
            return 0
          fi
        done
        return 1
      }
    '';

    # Block on inotify open/close events for the watched device nodes. The
    # outer loop handles unplug/replug — if all paths disappear, sleep briefly
    # and retry once they come back.
    eventLoop = ''
      # Handle a device that's already in use at service start.
      reconcile

      while true; do
        existing=()
        for device in "''${obsbot_devices[@]}"; do
          [ -e "$device" ] && existing+=("$device")
        done

        if [ "''${#existing[@]}" -eq 0 ]; then
          # Configured Obsbot devices aren't present (unplugged). Drop any
          # stale flag and poll for the device appearing.
          mark_inactive
          sleep 30
          continue
        fi

        while IFS= read -r _; do
          reconcile
        done < <(inotifywait -q -m -e open -e close "''${existing[@]}" 2>/dev/null || true)

        # inotifywait exited (typically a watched path was removed). Re-check
        # before looping so safeeyes state is correct during the gap.
        reconcile
        sleep 2
      done
    '';
  };
in
  lib.mkIf hasObsbot guard
