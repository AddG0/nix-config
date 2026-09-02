# Focal Utopia 2022 correction. The curve belongs to the headphones rather than
# to a host, so each host only names the device it feeds.
#
# Source — oratory1990's measurements, via AutoEq:
#   exact file: https://github.com/jaakkopasanen/AutoEq/blob/master/results/oratory1990/over-ear/Focal%20Utopia%202022/Focal%20Utopia%202022%20ParametricEQ.txt
#   browsable:  https://autoeq.app  (model "Focal Utopia 2022", source oratory1990)
#   upstream:   https://www.reddit.com/r/oratory1990/
#
# A subset of the published 10 bands: the two corrective cuts, plus the Harman
# bass shelf and its partner. Omitted are PK 1980 +2.9, PK 5018 +2.9,
# PK 10k +6.3, HSC 10k -3.1 — adding any of them means recomputing the preamp.
#
# Filters above ~5 kHz transfer worst: Q6 corrections there track the GRAS
# fixture's coupler and individual ear geometry, not the headphone alone.
{
  config,
  lib,
  ...
}: let
  cfg = config.audio.focalUtopia2022;
in {
  options.audio.focalUtopia2022 = {
    enable = lib.mkEnableOption "a Focal Utopia 2022 output sink applying the oratory1990 correction";

    target = lib.mkOption {
      type = lib.types.str;
      example = "alsa_output.usb-Chord_Electronics_Ltd_HugoTT2_413-001-01.analog-stereo";
      description = ''
        `node.name` of the sink the headphones are physically plugged into on
        this host. Find it with `wpctl status` or `pw-dump`.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    audio.eqSinks."focal-utopia-2022" = {
      displayName = "Focal Utopia";
      inherit (cfg) target;

      # Cascade peak over 20 Hz-20 kHz, referenced to 20 Hz and not to DC — the
      # shelf keeps climbing below that, but nothing musical lives there.
      # = 10^(-6.30/20); Nix has no pow(), so recompute by hand if you retune.
      preampMult = 0.484172;

      bands = [
        # Harman bass shelf and the wide cut that partners it: alone the shelf
        # would climb toward DC, the pair puts the lift around 100-150 Hz.
        # A preference target, not a correction — drop both (and preampMult = 1.0)
        # for the Utopia's own leaner balance.
        {
          shape = "lowshelf";
          freq = 105.0;
          q = 0.70;
          gain = 9.1;
        }
        {
          freq = 65.0;
          q = 0.33;
          gain = -5.4;
        }
        # Corrective cuts.
        {
          freq = 1227.0;
          q = 1.92;
          gain = -3.1;
        }
        {
          freq = 5972.0;
          q = 6.00;
          gain = -3.2;
        }
      ];
    };
  };
}
