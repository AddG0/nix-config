# Builds a PipeWire filter-chain graph from a list of biquads.
#
# Shared because a correction is described the same way wherever it lands: as an
# EQ sink in front of a device (see hosts/common/optional/nixos/audio/eq-sink.nix)
# or as `audioconvert.filter-graph` on a node the host declares itself, which is
# the only form that works when the node comes from `context.objects`.
{lib}: let
  shapes = {
    peaking = "bq_peaking";
    lowshelf = "bq_lowshelf";
    highshelf = "bq_highshelf";
    highpass = "bq_highpass";
    lowpass = "bq_lowpass";
  };
in {
  eqShapes = shapes;

  mkEqFilterGraph = {
    bands,
    preampMult ? 1.0,
    # null emits one chain and lets PipeWire replicate it across channels. A
    # channel list emits one chain each and names the ports, keeping the
    # port-to-channel mapping explicit — what the audioconvert form expects.
    channels ? null,
  }: let
    suffix = ch:
      if ch == null
      then ""
      else "_${ch}";
    preOf = ch: "preamp${suffix ch}";
    bandOf = ch: i: "eq${suffix ch}_${toString i}";
    chainOf = ch: [(preOf ch)] ++ lib.imap0 (i: _: bandOf ch i) bands;

    nodesFor = ch:
      [
        {
          type = "builtin";
          name = preOf ch;
          label = "linear";
          control = {
            "Mult" = preampMult;
            "Add" = 0.0;
          };
        }
      ]
      ++ lib.imap0 (i: b: {
        type = "builtin";
        name = bandOf ch i;
        label = shapes.${b.shape or "peaking"};
        # All bq_* share one port set, so Gain rides along unused on shapes that ignore it.
        control = {
          "Freq" = b.freq;
          "Q" = b.q;
          "Gain" = b.gain;
        };
      })
      bands;

    linksFor = ch: let
      c = chainOf ch;
    in
      lib.zipListsWith (a: b: {
        output = "${a}:Out";
        input = "${b}:In";
      })
      (lib.init c) (lib.tail c);

    chans =
      if channels == null
      then [null]
      else channels;
  in
    {
      nodes = lib.concatMap nodesFor chans;
      links = lib.concatMap linksFor chans;
    }
    // lib.optionalAttrs (channels != null) {
      inputs = map (ch: "${preOf ch}:In") channels;
      outputs = map (ch: "${lib.last (chainOf ch)}:Out") channels;
    };
}
