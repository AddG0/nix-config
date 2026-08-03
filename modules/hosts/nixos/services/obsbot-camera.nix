{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.obsbot-camera;

  cameraOpts = _: {
    options = {
      vendorId = lib.mkOption {
        type = lib.types.str;
        example = "3564";
        description = "USB idVendor. Identifies the camera for the udev rule and for V4L node discovery.";
      };

      productId = lib.mkOption {
        type = lib.types.str;
        example = "fef8";
        description = "USB idProduct. Identifies the camera for the udev rule and for V4L node discovery.";
      };

      format = {
        width = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          example = 3840;
          description = "Video capture width. Null to leave unset (application decides).";
        };
        height = lib.mkOption {
          type = lib.types.nullOr lib.types.int;
          default = null;
          example = 2160;
          description = "Video capture height. Null to leave unset (application decides).";
        };
        pixelformat = lib.mkOption {
          type = lib.types.nullOr (lib.types.enum ["MJPG" "YUYV" "H264"]);
          default = null;
          example = "MJPG";
          description = "Pixel format fourcc. Null to leave unset.";
        };
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

  mkApplyScript = name: camCfg: let
    settingsPairs = lib.mapAttrsToList (n: v: "${n}=${toString v}") camCfg.settings;
    settingsCSV = lib.concatStringsSep "," settingsPairs;
    settingsSpace = lib.concatStringsSep " " settingsPairs;
    fmt = camCfg.format;
    fmtParts =
      lib.optional (fmt.width != null) "width=${toString fmt.width}"
      ++ lib.optional (fmt.height != null) "height=${toString fmt.height}"
      ++ lib.optional (fmt.pixelformat != null) "pixelformat=${fmt.pixelformat}";
    fmtArg =
      if fmtParts != []
      then "--set-fmt-video=${lib.concatStringsSep "," fmtParts}"
      else "";
  in
    pkgs.writeShellScript "obsbot-apply-${name}.sh" ''
      set -eu
      DELAY_SECONDS='${toString camCfg.delaySeconds}'
      STEP='${toString camCfg.stepSize}'
      TOL=$((STEP/2))

      # PTZ controls live on the capture node, not the metadata one.
      DEV="$(${listNodes} | ${pkgs.gawk}/bin/awk '$1 == "${name}" && $3 ~ /:capture:/ { print $2; exit }')"
      if [ -z "$DEV" ]; then
        echo "no capture node for ${name} (${camCfg.vendorId}:${camCfg.productId})" >&2
        exit 1
      fi

      get() { ${pkgs.v4l-utils}/bin/v4l2-ctl -d "$DEV" --get-ctrl="$1" 2>/dev/null | ${pkgs.gnused}/bin/sed -n 's/.*: //p'; }
      abs() { n=$1; [ "$n" -lt 0 ] && n=$((-n)); echo "$n"; }

      sleep "$DELAY_SECONDS"

      ${lib.optionalString (fmtArg != "") ''
        ${pkgs.v4l-utils}/bin/v4l2-ctl -d "$DEV" '${fmtArg}' || true
      ''}

      # ~31s window; the camera ignores PTZ writes until settled, so the readback decides.
      backoff=1
      max_backoff=16
      while [ "$backoff" -le "$max_backoff" ]; do
        ${pkgs.v4l-utils}/bin/v4l2-ctl -d "$DEV" --set-ctrl='${settingsCSV}' || true
        sleep "$backoff"

        all_ok=1
        for kv in ${settingsSpace}; do
          key="''${kv%%=*}"; want="''${kv#*=}"
          have="$(get "$key" || true)"

          case "$key" in
            # pan/tilt quantize to STEP, so a readback never matches exactly
            pan_absolute|tilt_absolute)
              [ "$(abs $((have - want)))" -le "$TOL" ] || { all_ok=0; break; }
              ;;
            *) [ "''${have:-__nil__}" = "$want" ] || { all_ok=0; break; } ;;
          esac
        done

        [ "$all_ok" -eq 1 ] && exit 0
        backoff=$((backoff * 2))
      done

      exit 1
    '';

  camIdLines =
    lib.concatStringsSep "\n      "
    (lib.mapAttrsToList (name: c: ''["${name}"]="${c.vendorId}:${c.productId}"'') cfg.cameras);

  # Single source of truth for locating a camera's nodes — /dev/v4l/by-id paths
  # encode the USB product string and index, so they break on firmware changes.
  listNodes = pkgs.writeShellScript "obsbot-list-nodes.sh" ''
    set -eu
    declare -A CAM_IDS=(
      ${camIdLines}
    )
    for dev in /dev/video*; do
      [ -c "$dev" ] || continue
      info="$(${pkgs.systemd}/bin/udevadm info -q property -n "$dev" 2>/dev/null || true)"
      vendor="$(printf '%s\n' "$info" | ${pkgs.gnused}/bin/sed -n 's/^ID_VENDOR_ID=//p')"
      product="$(printf '%s\n' "$info" | ${pkgs.gnused}/bin/sed -n 's/^ID_MODEL_ID=//p')"
      caps="$(printf '%s\n' "$info" | ${pkgs.gnused}/bin/sed -n 's/^ID_V4L_CAPABILITIES=//p')"
      for cam in "''${!CAM_IDS[@]}"; do
        if [ "$vendor:$product" = "''${CAM_IDS[$cam]}" ]; then
          printf '%s %s %s\n' "$cam" "$dev" "$caps"
        fi
      done
    done
  '';

  watchScript = pkgs.writeShellScript "obsbot-watch.sh" ''
    set -euo pipefail
    PATH=${pkgs.inotify-tools}/bin:${pkgs.coreutils}/bin:${pkgs.systemd}/bin:$PATH
    # Apps open the device several times in a row; debounce per camera.
    COOLDOWN=8
    declare -A LAST=()

    declare -A OWNER=()
    PRESENT=()

    scan_present() {
      PRESENT=()
      OWNER=()
      while read -r cam dev _; do
        PRESENT+=("$dev")
        OWNER["$dev"]="$cam"
      done < <(${listNodes})
    }

    scan_present
    if [ ''${#PRESENT[@]} -eq 0 ]; then
      echo "no Obsbot camera nodes present; nothing to watch" >&2
      exit 0
    fi

    # udev starts us on the first node; wait for its siblings to settle in.
    for _ in $(seq 1 15); do
      before=''${#PRESENT[@]}
      sleep 0.2
      scan_present
      if [ ''${#PRESENT[@]} -eq "$before" ]; then
        break
      fi
    done

    # Process substitution, not a pipe: `exit` below must leave the script.
    exec 3< <(${pkgs.inotify-tools}/bin/inotifywait -q -m -e open -e delete_self "''${PRESENT[@]}")

    while read -r DEV EVENTS _ <&3; do
      # inotifywait lingers with zero watches after unplug; exit so udev restarts us.
      case "$EVENTS" in
        *DELETE_SELF*)
          exit 0
          ;;
      esac

      cam="''${OWNER[$DEV]:-}"
      if [ -z "$cam" ]; then
        continue
      fi

      now="$(${pkgs.coreutils}/bin/date +%s)"
      last="''${LAST[$cam]:-0}"
      if [ $((now - last)) -ge $COOLDOWN ]; then
        systemctl start "obsbot-apply@$cam.service"
        LAST[$cam]="$now"
      fi
    done

    # inotifywait died on its own; exit 0 would look like an unplug and silently
    # stop watching, since Restart=on-failure ignores it.
    echo "inotifywait exited unexpectedly" >&2
    exit 1
  '';
in {
  options.services.obsbot-camera = {
    enable = lib.mkEnableOption "Obsbot camera auto-configuration (on first open)";

    cameras = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule cameraOpts);
      default = {};
      description = "Per-camera configuration, keyed by name. Device nodes are discovered from the USB ids.";
      example = lib.literalExpression ''
        {
          obsbot-tiny-2 = {
            vendorId = "3564";
            productId = "fef8";
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

    listNodesScript = lib.mkOption {
      type = lib.types.path;
      internal = true;
      readOnly = true;
      default = listNodes;
      description = "Prints '<camera> <devnode> <v4l-caps>' per line for every present node of a configured camera. For consumers that need to watch the same devices.";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services =
      (lib.mapAttrs' (
          name: camCfg:
            lib.nameValuePair "obsbot-apply@${name}" {
              description = "Configure Obsbot controls for ${name}";
              serviceConfig = {
                Type = "oneshot";
                SyslogIdentifier = "obsbot-apply-${name}";
                ExecStart = "${mkApplyScript name camCfg}";
              };
            }
        )
        cfg.cameras)
      // lib.optionalAttrs (cfg.cameras != {}) {
        obsbot-watch = {
          description = "Watch V4L devices and apply Obsbot controls on first open";
          # udev covers hotplug; this covers a camera already attached at boot or rebuild.
          wantedBy = ["multi-user.target"];
          serviceConfig = {
            # A clean exit means unplugged; udev starts us again on replug.
            Restart = "on-failure";
            RestartSec = 10;
            SyslogIdentifier = "obsbot-watch";
            ExecStart = "${watchScript}";
          };
          # Backstop only: above what cable cycling produces, below a real storm.
          unitConfig = {
            StartLimitIntervalSec = 60;
            StartLimitBurst = 10;
          };
        };
      };

    # ATTRS walks the USB parent, so this needs no prior rule to have run.
    services.udev.extraRules = lib.optionalString (cfg.cameras != {}) (lib.concatMapStringsSep "\n" (camCfg: ''
        ACTION=="add", SUBSYSTEM=="video4linux", ATTRS{idVendor}=="${camCfg.vendorId}", ATTRS{idProduct}=="${camCfg.productId}", TAG+="systemd", ENV{SYSTEMD_WANTS}+="obsbot-watch.service"
      '')
      (lib.attrValues cfg.cameras));
  };
}
