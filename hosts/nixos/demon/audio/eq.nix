# Output sinks with their correction baked in. Pick an output and you pick its
# EQ; the Hugo stays selectable for an uncorrected feed.
#
# Both feed the same DAC because the Hugo drives its headphone jacks and its
# XLR/RCA outputs from one stage — it exposes a single stereo PCM with no jack
# detection, so nothing can switch the correction automatically.
_: let
  hugo = "alsa_output.usb-Chord_Electronics_Ltd_HugoTT2_413-001-01.analog-stereo";
in {
  audio.focalUtopia2022 = {
    enable = true;
    target = hugo;
  };

  audio.eqSinks.kw153 = {
    displayName = "KW153";
    target = hugo;

    # Cut-only, so no preamp is needed.
    preampMult = 1.0;

    # Least-squares fit against four swept measurements at different mic
    # positions. Two bands is the whole story: a third buys 0.04 dB, and the
    # ~3 dB residual is position variance no filter reaches.
    #
    # Left alone on purpose: 1600 Hz (-3.8 dB) is destructive interference, so
    # boosting spends headroom without filling it; 3150/6300 Hz read high only
    # because that is the SM7B's presence rise, not the speaker.
    #
    # Re-measure if the speaker or the room moves — 160 Hz swung 2.2-12.3 dB
    # across positions and is by far the most placement-sensitive band.
    bands = [
      {
        freq = 140.0;
        q = 3.0;
        gain = -6.0;
      }
      {
        freq = 225.0;
        q = 2.0;
        gain = -8.0;
      }
    ];
  };
}
