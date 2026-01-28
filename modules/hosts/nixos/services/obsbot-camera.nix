{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.obsbot-camera;

  # Camera submodule type
  cameraOpts = {name, ...}: {
    options = {
      triggerPaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [];
        example = [
          "/dev/v4l/by-id/usb-Vendor_Product-video-index0"
          "/dev/v4l/by-id/usb-Vendor_Product-video-index1"
        ];
        description = "V4L device paths to watch for OPEN events. When any of these are opened, controls are applied to controlPath.";
      };

      controlPath = lib.mkOption {
        type = lib.types.str;
        example = "/dev/v4l/by-id/usb-Vendor_Product-video-index0";
        description = "V4L device path for PTZ controls (usually index0).";
      };

      settings = lib.mkOption {
        type = lib.types.attrs;
        default = {
          pan_absolute = 0;
          tilt_absolute = 0;
          zoom_absolute = 0;
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
  };

  # Generate apply script for a specific camera
  mkApplyScript = name: camCfg: let
    settingsPairs = lib.mapAttrsToList (n: v: "${n}=${toString v}") camCfg.settings;
    settingsCSV = lib.concatStringsSep "," settingsPairs;
    settingsSpace = lib.concatStringsSep " " settingsPairs;
  in
    pkgs.writeShellScript "obsbot-apply-${name}.sh" ''
      set -eu
      DEV='${camCfg.controlPath}'
      DELAY_SECONDS='${toString camCfg.delaySeconds}'
      STEP='${toString camCfg.stepSize}'
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

  # Build mapping of trigger paths to camera names
  triggerMap = lib.concatMapAttrs (name: camCfg:
    lib.listToAttrs (map (path: lib.nameValuePair path name) camCfg.triggerPaths)
  ) cfg.cameras;

  # All trigger paths across all cameras
  allTriggerPaths = lib.concatLists (lib.mapAttrsToList (_: camCfg: camCfg.triggerPaths) cfg.cameras);

  watchScript = pkgs.writeShellScript "obsbot-watch.sh" ''
    set -eu
    PATH=${pkgs.inotify-tools}/bin:${pkgs.coreutils}/bin:${pkgs.systemd}/bin:$PATH
    COOLDOWN=8
    declare -A LAST=()

    # Mapping of trigger paths to camera names
    declare -A TRIGGER_MAP=(
      ${lib.concatStringsSep "\n      " (lib.mapAttrsToList (path: name: ''["${path}"]="${name}"'') triggerMap)}
    )

    ${pkgs.inotify-tools}/bin/inotifywait -m -e open ${lib.concatStringsSep " " allTriggerPaths} 2>/dev/null |
    while read -r DEV _ _; do
      # Look up which camera this trigger path belongs to
      cam="''${TRIGGER_MAP[$DEV]:-}"
      if [ -z "$cam" ]; then
        continue
      fi

      now="$(${pkgs.coreutils}/bin/date +%s)"
      last="''${LAST[$cam]:-0}"
      if [ $((now - last)) -ge $COOLDOWN ]; then
        systemctl --user start "obsbot-apply@$cam.service"
        LAST[$cam]="$now"
      fi
    done
  '';
in {
  options.services.obsbot-camera = {
    enable = lib.mkEnableOption "Obsbot camera auto-configuration (on first open)";

    cameras = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule cameraOpts);
      default = {};
      description = "Per-camera configuration. Each camera has trigger paths (to watch) and a control path (to apply settings).";
      example = lib.literalExpression ''
        {
          obsbot-tiny-2 = {
            triggerPaths = [
              "/dev/v4l/by-id/usb-Remo_Tech_Co.__Ltd._OBSBOT_Tiny_2-video-index0"
              "/dev/v4l/by-id/usb-Remo_Tech_Co.__Ltd._OBSBOT_Tiny_2-video-index1"
            ];
            controlPath = "/dev/v4l/by-id/usb-Remo_Tech_Co.__Ltd._OBSBOT_Tiny_2-video-index0";
            settings = {
              pan_absolute = 20000;
              tilt_absolute = -50000;
              zoom_absolute = 10;
              focus_automatic_continuous = 1;
            };
          };
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.user.services =
      # Per-camera oneshot apply services
      (lib.mapAttrs' (name: camCfg:
        lib.nameValuePair "obsbot-apply@${name}" {
          description = "Configure Obsbot controls for ${name}";
          serviceConfig = {
            Type = "oneshot";
            SyslogIdentifier = "obsbot-apply-${name}";
            ExecStart = "${mkApplyScript name camCfg}";
          };
        }
      ) cfg.cameras)
      # Watcher that triggers apply on first OPEN
      // lib.optionalAttrs (allTriggerPaths != []) {
        obsbot-watch = {
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
  };
}
