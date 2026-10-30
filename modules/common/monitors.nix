# Set per host; home/common/core/monitors.nix hands the host's values to home-manager.
{
  lib,
  config,
  ...
}: {
  options.display = {
    monitors = lib.mkOption {
      type = lib.types.listOf (
        lib.types.submodule ({config, ...}: {
          options = {
            output = lib.mkOption {
              type = lib.types.str;
              example = "DP-1";
              description = "Compositor output / connector identifier (e.g. DP-1, eDP-1, HDMI-A-1).";
            };
            name = lib.mkOption {
              type = lib.types.str;
              default = config.output;
              defaultText = lib.literalExpression "config.output";
              example = "main";
              description = ''
                Friendly human-readable name for this monitor. Defaults to the
                output identifier. Used where a human-meaningful label is
                preferable to the connector name (e.g. wpaperd folder paths).
              '';
            };
            primary = lib.mkOption {
              type = lib.types.bool;
              default = false;
            };
            width = lib.mkOption {
              type = lib.types.int;
              example = 1920;
            };
            height = lib.mkOption {
              type = lib.types.int;
              example = 1080;
            };
            refreshRate = lib.mkOption {
              type = lib.types.int;
              default = 60;
            };
            x = lib.mkOption {
              type = lib.types.int;
              default = 0;
            };
            y = lib.mkOption {
              type = lib.types.int;
              default = 0;
            };
            scale = lib.mkOption {
              type = lib.types.number;
              default = 1.0;
            };
            transform = lib.mkOption {
              type = lib.types.enum ["normal" "90" "180" "270" "flipped" "flipped-90" "flipped-180" "flipped-270"];
              default = "normal";
            };
            enabled = lib.mkOption {
              type = lib.types.bool;
              default = true;
            };
            workspace = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
            };
            vrr = lib.mkOption {
              type = lib.types.enum ["off" "on" "fullscreen-only" "fullscreen-game"];
              description = "Variable Refresh Rate (Adaptive Sync / FreeSync). `fullscreen-game` limits it to fullscreen windows whose content type is game or video.";
              default = "off";
            };
            bitdepth = lib.mkOption {
              type = lib.types.enum [8 10];
              description = "Color bit depth. 10 enables HDR.";
              default = 8;
            };
            hdr = lib.mkOption {
              type = lib.types.bool;
              description = "Enable HDR color management.";
              default = false;
            };
            sdrMaxLuminance = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.positive;
              description = "Nits SDR white is shown at on an HDR output; null keeps Hyprland's 80.";
              default = null;
            };
            sdrMinLuminance = lib.mkOption {
              type = lib.types.nullOr (lib.types.numbers.between 0 10);
              description = "Nits SDR black is shown at on an HDR output; null keeps Hyprland's 0.2.";
              default = null;
            };
            sdrBrightness = lib.mkOption {
              type = lib.types.nullOr lib.types.float;
              description = "Multiplier on SDR content's encoded output on an HDR output; prefer sdrMaxLuminance.";
              default = null;
            };
            sdrSaturation = lib.mkOption {
              type = lib.types.nullOr lib.types.float;
              description = "Saturation multiplier for SDR content on an HDR output.";
              default = null;
            };
            sdrEotf = lib.mkOption {
              type = lib.types.nullOr (lib.types.enum ["default" "auto" "srgb" "gamma22" "gamma22force"]);
              description = "Transfer function SDR content is decoded with; null follows render.cm_sdr_eotf.";
              default = null;
            };
            supportsWideColor = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              description = "Override the EDID's wide-color support; null trusts the EDID.";
              default = null;
            };
            supportsHdr = lib.mkOption {
              type = lib.types.nullOr lib.types.bool;
              description = "Override the EDID's HDR support; null trusts the EDID.";
              default = null;
            };
            minLuminance = lib.mkOption {
              type = lib.types.nullOr (lib.types.numbers.between 0 10);
              description = "Panel black in nits; null uses the EDID.";
              default = null;
            };
            maxLuminance = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.positive;
              description = "Panel peak in nits; null uses the EDID.";
              default = null;
            };
            maxAvgLuminance = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.positive;
              description = "Panel full-frame average peak in nits; null uses the EDID.";
              default = null;
            };
            icc = lib.mkOption {
              type = lib.types.nullOr lib.types.path;
              description = "ICC profile applied to this output.";
              default = null;
            };
            mirror = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              description = "Output name to mirror instead of extending the layout.";
              default = null;
            };
            reserved = lib.mkOption {
              type = lib.types.nullOr (lib.types.submodule {
                options = lib.genAttrs ["top" "bottom" "left" "right"] (_:
                  lib.mkOption {
                    type = lib.types.ints.unsigned;
                    default = 0;
                  });
              });
              description = "Pixels kept clear of tiled windows on each edge.";
              default = null;
            };
            oled = lib.mkOption {
              type = lib.types.bool;
              description = "Whether this monitor is OLED (used for burn-in protection automation).";
              default = false;
            };
          };
        })
      );
      default = [];
    };

    defaultMonitor.enable = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to add a catch-all rule for unspecified monitors.";
    };
  };

  config = {
    assertions = [
      {
        assertion =
          ((lib.length config.display.monitors) != 0)
          -> ((lib.length (lib.filter (m: m.primary) config.display.monitors)) == 1);
        message = "Exactly one monitor must be set to primary.";
      }
    ];
  };
}
