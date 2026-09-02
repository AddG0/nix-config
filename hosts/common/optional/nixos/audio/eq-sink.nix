# A PipeWire sink that runs a biquad cascade and forwards to a real device, so
# choosing an output also chooses its correction.
#
# Not `audioconvert.filter-graph` on the device node: set through WirePlumber's
# monitor rules that property lands on the node and is never read, so the graph
# silently never instantiates. It is honoured only as adapter construction args,
# i.e. on a `context.objects` node (freya's laptop speakers) — which a
# hot-plugged USB DAC that WirePlumber owns is not.
#
# `pw-cli enum-params <id> PropInfo` tells the two apart: a live graph lists
# every band as `<band>:Freq`/`:Q`/`:Gain`; an empty list means silent failure.
{
  config,
  lib,
  ...
}: let
  cfg = config.audio.eqSinks;
in {
  options.audio.eqSinks = lib.mkOption {
    default = {};
    description = ''
      EQ sinks to create, keyed by node name. Each appears as a selectable
      output and forwards to `target` after filtering.
    '';
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        displayName = lib.mkOption {
          type = lib.types.str;
          description = "Name shown in output pickers.";
        };
        target = lib.mkOption {
          type = lib.types.str;
          description = "`node.name` of the real sink this feeds.";
        };
        preampMult = lib.mkOption {
          type = lib.types.number;
          default = 1.0;
          description = ''
            Linear multiplier applied ahead of the bands, to hold the cascade's
            worst-case sum below 0 dBFS. A cut-only cascade needs none.
            Given as a multiplier rather than dB because Nix has no pow() —
            it is 10^(dB/20), and must be recomputed by hand when a band changes.
          '';
        };
        bands = lib.mkOption {
          description = "Biquads, applied in order.";
          type = lib.types.listOf (lib.types.submodule {
            options = {
              shape = lib.mkOption {
                type = lib.types.enum (builtins.attrNames lib.custom.eqShapes);
                default = "peaking";
                description = "Biquad shape.";
              };
              freq = lib.mkOption {
                type = lib.types.number;
                description = "Centre frequency for peaking, corner for a shelf.";
              };
              q = lib.mkOption {
                type = lib.types.number;
                description = "Q. Higher is narrower.";
              };
              gain = lib.mkOption {
                type = lib.types.number;
                description = "Gain in dB. Negative cuts.";
              };
            };
          });
        };
      };
    });
  };

  config = lib.mkIf (cfg != {}) {
    services.pipewire.extraConfig.pipewire = lib.mapAttrs' (nodeName: sink:
      lib.nameValuePair "99-eq-sink-${nodeName}" {
        "context.modules" = [
          {
            name = "libpipewire-module-filter-chain";
            args = {
              "node.description" = sink.displayName;
              "media.name" = sink.displayName;
              "filter.graph" = lib.custom.mkEqFilterGraph {inherit (sink) bands preampMult;};
              "audio.channels" = 2;
              "audio.position" = ["FL" "FR"];
              "capture.props" = {
                "node.name" = nodeName;
                "media.class" = "Audio/Sink";
              };
              # Passive: nothing runs until something plays into the sink.
              "playback.props" = {
                "node.name" = "${nodeName}_out";
                "node.passive" = true;
                "target.object" = sink.target;
              };
            };
          }
        ];
      })
    cfg;
  };
}
