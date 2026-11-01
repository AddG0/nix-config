# display.monitors rendered as SDDM's KWin layout, run against a fake DRM sysfs tree.
{
  pkgs,
  lib,
  harness,
  ...
}: let
  monitors =
    (harness.eval [
      (harness.root + "/modules/common/monitors.nix")
      {
        display.monitors = [
          {
            output = "DP-1";
            x = 0;
            width = 1920;
            height = 1080;
          }
          {
            output = "DP-4";
            x = 1920;
            width = 2560;
            height = 1440;
            primary = true;
          }
          {
            output = "HDMI-A-2";
            x = 4480;
            y = -240;
            width = 1920;
            height = 1080;
            scale = 1.5;
            transform = "90";
          }
        ];
      }
    ])
    .display
    .monitors;

  render = ms: lib.getExe (import ../_kwin-outputs.nix {inherit lib pkgs;} ms);
in
  harness.bats "display-managers" [./kwin-outputs.bats] {
    nativeBuildInputs = [pkgs.jq];
    kwinOutputs = render monitors;
    kwinOutputsSingle = render [(lib.last monitors)];
  }
