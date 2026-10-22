# display.monitors entries rendered as Hyprland monitorv2 blocks.
{
  harness,
  lib,
  ...
}: let
  hyprLib = import ../lib.nix {inherit lib;};

  base = {
    output = "DP-3";
    width = 3840;
    height = 2160;
    refreshRate = 240;
    x = 3840;
    y = 0;
    primary = true;
  };

  render = monitor:
    hyprLib.monitorv2 (builtins.head
      (harness.eval [
        (harness.root + "/modules/home/monitors.nix")
        {display.monitors = [monitor];}
      ])
      .display
      .monitors);
in {
  "test a plain monitor renders only mode, position, scale, transform and vrr" = {
    expr = render base;
    expected = {
      output = "DP-3";
      mode = "3840x2160@240.0";
      position = "3840x0";
      scale = "1.000000";
      transform = 0;
      vrr = 0;
    };
  };

  "test an HDR monitor renders bitdepth, cm and SDR white luminance" = {
    expr = render (base
      // {
        bitdepth = 10;
        hdr = true;
        sdrMaxLuminance = 203;
      });
    expected = {
      output = "DP-3";
      mode = "3840x2160@240.0";
      position = "3840x0";
      scale = "1.000000";
      transform = 0;
      vrr = 0;
      bitdepth = 10;
      cm = "hdr";
      sdr_max_luminance = 203;
    };
  };

  "test EDID overrides render as Hyprland's integer flags and luminance keys" = {
    expr = lib.getAttrs ["supports_wide_color" "supports_hdr" "min_luminance" "max_luminance" "max_avg_luminance" "sdr_eotf"] (render (base
      // {
        supportsWideColor = true;
        supportsHdr = false;
        minLuminance = 0.0;
        maxLuminance = 603;
        maxAvgLuminance = 276;
        sdrEotf = "gamma22";
      }));
    expected = {
      supports_wide_color = 1;
      supports_hdr = 0;
      min_luminance = 0.0;
      max_luminance = 603;
      max_avg_luminance = 276;
      sdr_eotf = "gamma22";
    };
  };

  "test reserved edges render in Hyprland's top, bottom, left, right order" = {
    expr =
      (render (base
        // {
          reserved = {
            top = 40;
            right = 4;
          };
        }))
      .addreserved;
    expected = "40, 0, 0, 4";
  };

  "test transform and vrr names map to Hyprland's numbers" = {
    expr = lib.getAttrs ["transform" "vrr"] (render (base
      // {
        transform = "270";
        vrr = "fullscreen-game";
      }));
    expected = {
      transform = 3;
      vrr = 3;
    };
  };

  "test a disabled monitor renders only its output and the disabled flag" = {
    expr = render (base // {enabled = false;});
    expected = {
      output = "DP-3";
      disabled = true;
    };
  };
}
