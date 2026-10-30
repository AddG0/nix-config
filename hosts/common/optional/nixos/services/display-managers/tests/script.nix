# display.monitors rendered as SDDM's KWin layout, run against a fake DRM sysfs tree.
{
  pkgs,
  lib,
  harness,
  ...
}: let
  monitors =
    (harness.eval [
      (harness.root + "/modules/home/monitors.nix")
      {
        display.monitors = [
          {
            output = "DP-2";
            x = 0;
            width = 3840;
            height = 2160;
          }
          {
            output = "DP-3";
            x = 3840;
            width = 3840;
            height = 2160;
            primary = true;
          }
          {
            output = "HDMI-A-1";
            x = 7680;
            y = -732;
            width = 3840;
            height = 2160;
            scale = 1.2;
            transform = "270";
          }
        ];
      }
    ])
    .display
    .monitors;

  kwinOutputs = lib.getExe (import ../_kwin-outputs.nix {inherit lib pkgs;} monitors);
  jq = lib.getExe pkgs.jq;
in
  harness.check "display-managers" ''
    mkdir -p drm/card1-DP-2 drm/card1-DP-3 drm/card1-HDMI-A-1
    printf 'left' > drm/card1-DP-2/edid
    printf 'main' > drm/card1-DP-3/edid
    printf 'right' > drm/card1-HDMI-A-1/edid

    ${kwinOutputs} drm out/kwinoutputconfig.json
    ${jq} -c '.[0].data[] | [.connectorName, .edidHash, .scale, .transform]' out/kwinoutputconfig.json > outputs
    printf '%s\n' \
      "[\"DP-2\",\"$(printf left | md5sum | cut -d' ' -f1)\",1.0,\"Normal\"]" \
      "[\"DP-3\",\"$(printf main | md5sum | cut -d' ' -f1)\",1.0,\"Normal\"]" \
      "[\"HDMI-A-1\",\"$(printf right | md5sum | cut -d' ' -f1)\",1.2,\"Rotated270\"]" \
      | diff -u - outputs \
      || { echo "FAIL each output carries its connector's EDID md5, scale and KWin transform name" >&2; exit 1; }

    ${jq} -c '.[1].data[0].outputs[] | [.outputIndex, .position.x, .position.y, .priority, .enabled]' out/kwinoutputconfig.json > setup
    printf '%s\n' '[0,0,0,1,true]' '[1,3840,0,0,true]' '[2,7680,-732,2,true]' | diff -u - setup \
      || { echo "FAIL the setup keeps display.monitors positions and makes the primary monitor priority 0" >&2; exit 1; }

    mkdir -p drm/card2-DP-3
    : > drm/card2-DP-3/edid
    ${kwinOutputs} drm out/kwinoutputconfig.json
    [ "$(${jq} -r '.[0].data[1].edidHash' out/kwinoutputconfig.json)" = "$(printf main | md5sum | cut -d' ' -f1)" ] \
      || { echo "FAIL a disconnected connector of the same name on another GPU does not hide the connected one's EDID" >&2; exit 1; }

    : > drm/card1-HDMI-A-1/edid
    ${kwinOutputs} drm out/kwinoutputconfig.json 2>err.log
    [ "$(${jq} -r '.[0].data[2].edidHash' out/kwinoutputconfig.json)" = "" ] \
      || { echo "FAIL a connector with an empty EDID gets no hash" >&2; exit 1; }
    grep -q "no EDID for HDMI-A-1 under drm" err.log \
      || { cat err.log >&2; echo "FAIL a missing EDID is reported with its connector and sysfs dir" >&2; exit 1; }
  ''
