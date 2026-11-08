# Wakes a powered-off or suspended host for git-sync's schedule: boot, shutdown and suspend set the RTC alarm, and the boot or resume it causes runs git-sync, then returns the host.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.nix.git-sync;
  alarmRecord = "$STATE_DIRECTORY/wake-alarm";
  # Boot or resume plus network come up well inside this; a later one was someone pressing the button.
  wakeWindowSeconds = 600;
  inherit (cfg) stateDirectory;
  needsReboot = lib.getExe (lib.callPackageWith pkgs ./needs-reboot.nix {});

  armWake = pkgs.writeShellApplication {
    name = "nix-remote-rebuild-arm-wake";
    runtimeInputs = with pkgs; [systemd coreutils gawk];
    text = ''
      wakealarm=''${WAKEALARM:-/sys/class/rtc/rtc0/wakealarm}

      # systemd-analyze omits the "(in UTC)" line when local time already is UTC.
      next=$(systemd-analyze calendar ${lib.escapeShellArg cfg.schedule} | awk -F': ' '/Next elapse:|\(in UTC\):/ {n = $2} END {print n}')
      if [ -z "$next" ] || [ "$next" = never ]; then
        echo "git-sync schedule ${lib.escapeShellArg cfg.schedule} has no next elapse ('$next'); no wake alarm set." >&2
        exit 1
      fi
      at=$(date -d "$next" +%s)

      # The kernel refuses a new alarm while another is still set.
      echo 0 >"$wakealarm"
      echo "$at" >"$wakealarm"
      echo "$at" >"${alarmRecord}"
      echo "Wake alarm set for $next."
    '';
  };

  wokenByAlarm = pkgs.writeShellApplication {
    name = "nix-remote-rebuild-woken-by-alarm";
    runtimeInputs = [pkgs.coreutils];
    text = ''
      if [ ! -f "${alarmRecord}" ]; then
        echo "No wake alarm on record; staying on."
        exit 1
      fi
      at=$(cat "${alarmRecord}")
      now=$(date +%s)
      if [ "$now" -lt "$at" ] || [ "$now" -gt $((at + ${toString wakeWindowSeconds})) ]; then
        echo "Woke at $(date -d "@$now"), not by the wake alarm for $(date -d "@$at"); staying on."
        exit 1
      fi
      echo "Woken by the alarm for $(date -d "@$at"); checking for an update, then returning to the state it woke from."
    '';
  };

  # $1 is what the alarm woke the host from: poweroff or suspend.
  syncThenReturnTo = pkgs.writeShellApplication {
    name = "nix-remote-rebuild-then-return-to";
    runtimeInputs = with pkgs; [systemd coreutils];
    text = ''
      built=''${BUILT_SYSTEM:-/nix/var/nix/profiles/system}

      # Starts the run, or joins the timer's after a resume, where a run missed in suspend still fires.
      systemctl start nix-remote-rebuild.service ||
        echo "nix-remote-rebuild failed (exit $?); see journalctl -u nix-remote-rebuild. Returning to $1 anyway." >&2

      case "$1" in
        poweroff) systemctl poweroff ;;
        suspend)
          if ${needsReboot} "$built"; then
            echo "Powering off instead of suspending, so the next start boots the rebuild."
            systemctl poweroff
          else
            systemctl suspend
          fi
          ;;
        *)
          echo "Unknown state to return to '$1'; expected poweroff or suspend." >&2
          exit 2
          ;;
      esac
    '';
  };

  onAlarmWake = wokenFrom: {
    description = "Run git-sync, then return to ${wokenFrom}, when the RTC alarm woke the host";
    # The rebuild it waits on switches the system; a restart would cancel the return.
    restartIfChanged = false;
    serviceConfig = {
      StateDirectory = stateDirectory;
      ExecCondition = "${wokenByAlarm}/bin/nix-remote-rebuild-woken-by-alarm";
      ExecStart = "${syncThenReturnTo}/bin/nix-remote-rebuild-then-return-to ${wokenFrom}";
    };
  };
in {
  options.nix.git-sync.wakeForSchedule = lib.mkEnableOption ''
    waking the host from poweroff or suspend for each `schedule` run through the RTC alarm, then
    returning it to the state it woke from. A run due while the host is off waits for the next
    alarm instead of running when someone starts the host. When the run leaves an update for the
    next boot, the host powers off instead of suspending, so its next start boots the update.
    Requires `schedule` and `reboot = "never"`. Waking from poweroff needs firmware that honours
    RTC wake from S5, often only with ErP disabled'';

  config = lib.mkIf (cfg.enable && cfg.wakeForSchedule) {
    assertions = [
      {
        assertion = cfg.schedule != null;
        message = "nix.git-sync.wakeForSchedule needs 'schedule': an 'interval' has no wall-clock time to wake at";
      }
      {
        # A reboot re-arms tomorrow's alarm, so the boot after it is not an alarm wake and stays on.
        assertion = cfg.reboot == "never";
        message = "nix.git-sync.wakeForSchedule puts the host back to sleep after the rebuild; set 'reboot' to \"never\"";
      }
    ];

    systemd = {
      # The alarm wakes the host for the run; catching up at a hand start would build while someone uses it.
      timers.nix-remote-rebuild.timerConfig.Persistent = lib.mkForce false;

      services = {
        # Armed at boot as well as at shutdown, so a held power button or a power cut still wakes it.
        nix-remote-rebuild-arm-wake = {
          description = "Keep the RTC alarm set for the next git-sync run";
          wantedBy = ["multi-user.target"];
          # The boot's alarm check reads the record before re-arming overwrites it.
          after = ["nix-remote-rebuild-on-alarm-boot.service"];
          serviceConfig = {
            Type = "oneshot";
            RemainAfterExit = true;
            StateDirectory = stateDirectory;
            ExecStart = "${armWake}/bin/nix-remote-rebuild-arm-wake";
            ExecStop = "${armWake}/bin/nix-remote-rebuild-arm-wake";
          };
        };

        nix-remote-rebuild-arm-wake-before-suspend = {
          description = "Set the RTC alarm for the next git-sync run before the host suspends";
          wantedBy = ["suspend.target"];
          before = ["systemd-suspend.service"];
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = stateDirectory;
            ExecStart = "${armWake}/bin/nix-remote-rebuild-arm-wake";
          };
        };

        nix-remote-rebuild-on-alarm-boot = lib.recursiveUpdate (onAlarmWake "poweroff") {
          wantedBy = ["multi-user.target"];
          after = ["network-online.target"];
          wants = ["network-online.target"];
          # Not oneshot: multi-user.target must not wait on a rebuild that switches the system under it.
          serviceConfig.Type = "exec";
        };

        nix-remote-rebuild-on-alarm-resume = lib.recursiveUpdate (onAlarmWake "suspend") {
          wantedBy = ["suspend.target"];
          after = ["suspend.target"];
          # Not oneshot: its own `systemctl suspend` would wait on this unit's still-running start job.
          serviceConfig.Type = "exec";
        };
      };
    };
  };
}
