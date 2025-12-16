{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.obsbot-camera;

  settingsPairs = lib.mapAttrsToList (n: v: "${n}=${toString v}") cfg.settings;
  settingsCSV = lib.concatStringsSep "," settingsPairs;
  settingsSpace = lib.concatStringsSep " " settingsPairs;

  applyScript = pkgs.writeShellScript "obsbot-apply.sh" ''
    set -eu
    DEV="/dev/$1"
    DELAY_SECONDS='${toString cfg.delaySeconds}'
    STEP='${toString cfg.stepSize}'
    TOL=$((STEP/2))

    get() { ${pkgs.v4l-utils}/bin/v4l2-ctl -d "$DEV" --get-ctrl="$1" 2>/dev/null | ${pkgs.gnused}/bin/sed -n 's/.*: //p'; }
    abs() { n=$1; [ "$n" -lt 0 ] && n=$((-n)); echo "$n"; }

    sleep "$DELAY_SECONDS"

    # Try up to 5 times: set, wait, verify with tolerance for stepped PTZ
    i=1
    while [ "$i" -le 5 ]; do
      ${pkgs.v4l-utils}/bin/v4l2-ctl -d "$DEV" --set-ctrl='${settingsCSV}' || true
      sleep 1

      all_ok=1
      for kv in ${settingsSpace}; do
        key="''${kv%%=*}"; want="''${kv#*=}"
        have="$(get "$key" || true)"

        case "$key" in
          pan_absolute|tilt_absolute)
            [ "$(abs $((have - want)))" -le "$TOL" ] || { all_ok=0; break; }
            ;;
          *) [ "''${have:-__nil__}" = "$want" ] || { all_ok=0; break; } ;;
        esac
      done

      [ "$all_ok" -eq 1 ] && exit 0
      i=$((i+1))
    done

    exit 1
  '';

  watchScript = pkgs.writeShellScript "obsbot-watch.sh" ''
    set -eu
    PATH=${pkgs.inotify-tools}/bin:${pkgs.coreutils}/bin:${pkgs.systemd}/bin:$PATH
    COOLDOWN=8
    declare -A LAST=()

    ${pkgs.inotify-tools}/bin/inotifywait -m -e open ${lib.concatStringsSep " " cfg.devicePaths} 2>/dev/null |
    while read -r DEV _ _; do
      base="$(${pkgs.coreutils}/bin/basename "$DEV")"
      now="$(${pkgs.coreutils}/bin/date +%s)"
      last="''${LAST[$base]:-0}"
      if [ $((now - last)) -ge $COOLDOWN ]; then
        systemctl --user start "obsbot-apply@$base.service"
        LAST[$base]="$now"
      fi
    done
  '';
in {
  options.services.obsbot-camera = {
    enable = lib.mkEnableOption "Obsbot camera auto-configuration (on first open)";

    devicePaths = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = ["/dev/video0"]; # your PTZ node
      description = "V4L device nodes to watch for OPEN events.";
    };

    settings = lib.mkOption {
      type = lib.types.attrs;
      default = {
        pan_absolute = 20000;
        tilt_absolute = -50000;
        zoom_absolute = 10;
        focus_automatic_continuous = 1;
      };
      description = "Controls to set via v4l2-ctl.";
    };

    delaySeconds = lib.mkOption {
      type = lib.types.int;
      default = 3;
      description = "Sleep before first apply to let the camera initialize.";
    };

    stepSize = lib.mkOption {
      type = lib.types.int;
      default = 3600;
      description = "Driver step for pan/tilt; used to allow ±step/2 tolerance.";
    };
  };

  config = lib.mkIf cfg.enable {
    # Per-device oneshot apply with delay + verify
    systemd.user.services."obsbot-apply@" = {
      description = "Configure Obsbot controls for %I";
      serviceConfig = {
        Type = "oneshot";
        SyslogIdentifier = "obsbot-apply";
        ExecStart = "${applyScript} %I";
      };
    };

    # Watcher that triggers apply on first OPEN
    systemd.user.services.obsbot-watch = {
      description = "Watch V4L devices and apply Obsbot controls on first open";
      wantedBy = ["default.target"];
      after = ["default.target"];
      serviceConfig = {
        Restart = "always";
        RestartSec = 2;
        ExecStart = "${watchScript}";
      };
    };
  };
}
