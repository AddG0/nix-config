{
  lib,
  pkgs,
  ...
}: let
  # These default off under the generic topology.
  controls = [
    "Speaker Switch"
    "rt1320-1 OT23 L Switch" # RT1320 amp left output terminal
    "rt1320-1 OT23 R Switch" # RT1320 amp right output terminal
    "Dmic0 Capture Switch" # built-in digital mic array
  ];
  amixer = "${pkgs.alsa-utils}/bin/amixer";
  setOn = lib.concatMapStringsSep "\n" (c: ''${amixer} -c sofsoundwire cset name="${c}" on'') controls;

  # The generic topology loads no vendor coefficients — the `Post Mixer Speaker
  # Playback IIR/FIR Eq bytes` controls are empty and the DRC switch is off — so the
  # amp gets an unshaped feed. These are by ear, not measured.
  eqBands = [
    # Measured by ear 2026-08-26: 60/90/120 Hz are inaudible, 180 Hz is not, so
    # nothing below ~150 Hz is tone — it is excursion that smears the midrange.
    # Cascaded for 4th-order slope; a single biquad is too gentle to clear it.
    {
      label = "bq_highpass";
      freq = 140.0;
      q = 0.7;
      gain = 0.0;
    }
    {
      label = "bq_highpass";
      freq = 140.0;
      q = 0.7;
      gain = 0.0;
    }
    {
      label = "bq_peaking";
      freq = 300.0;
      q = 1.0;
      gain = 2.5;
    } # body, kept above the measured knee rather than on it
    {
      label = "bq_peaking";
      freq = 700.0;
      q = 1.2;
      gain = -3.5;
    } # small-enclosure boxiness
    {
      label = "bq_peaking";
      freq = 2000.0;
      q = 1.5;
      gain = -2.0;
    } # shout / listening fatigue
    {
      label = "bq_peaking";
      freq = 4500.0;
      q = 1.0;
      gain = 2.0;
    } # vocal presence
    {
      label = "bq_highshelf";
      freq = 10000.0;
      q = 0.7;
      gain = 1.5;
    } # air
  ];

  # Holds the worst-case overlapping band sum at 0 dBFS: the RT1320 runs open-loop
  # (`R0 Calibration` off, no I/V sense), so nothing downstream catches a clip.
  # = 10^(-3/20); Nix has no pow(), so recompute by hand if you retune.
  preampMult = 0.7079457843841379;

  # A graph with fewer ports than channels gets replicated; both are spelled out so
  # the port-to-channel mapping stays explicit.
  eqChannels = ["FL" "FR"];
  preampOf = ch: "preamp_${ch}";
  bandOf = ch: i: "eq_${ch}_${toString i}";
  chainOf = ch: [(preampOf ch)] ++ lib.imap0 (i: _: bandOf ch i) eqBands;

  filterGraph = {
    nodes = lib.concatMap (ch:
      [
        {
          type = "builtin";
          name = preampOf ch;
          label = "linear";
          control = {"Mult" = preampMult;};
        }
      ]
      ++ lib.imap0 (i: b: {
        type = "builtin";
        name = bandOf ch i;
        inherit (b) label;
        # All bq_* share one port set, so Gain rides along unused on the highpass.
        control = {
          "Freq" = b.freq;
          "Q" = b.q;
          "Gain" = b.gain;
        };
      })
      eqBands)
    eqChannels;
    links = lib.concatMap (ch: let
      c = chainOf ch;
    in
      lib.zipListsWith (a: b: {
        output = "${a}:Out";
        input = "${b}:In";
      }) (lib.init c) (lib.tail c))
    eqChannels;
    inputs = map (ch: "${preampOf ch}:In") eqChannels;
    outputs = map (ch: "${lib.last (chainOf ch)}:Out") eqChannels;
  };
in {
  # FLAKE-UPDATE: drop this whole module once the pinned kernel gains a SoundWire
  # machine driver for the RT721+RT1320 combo. Re-check after a kernel bump: if
  # `dmesg | grep -i "No SoundWire machine driver"` is gone and real speaker/mic
  # nodes appear, remove.
  #
  # Razer Blade 16 (Panther Lake) internal audio — RT721 jack + RT1320 amp + DMIC.
  #
  # Without a machine driver the card falls back to generic function topologies and
  # carries no ALSA components string, so UCM cannot match it either
  # (snd_use_case_mgr_open fails with -2). PipeWire is left on its own
  # `stereo-fallback` profile: one headphone-DAC sink, no sources, and the speaker
  # amp and DMIC PCMs unclaimed with their switches off.

  # Devices 2 and 10 are what is left — the fallback profile takes 0, HDMI takes
  # 5-7. Address by card name; the card index moves between boots.
  services.pipewire.extraConfig.pipewire."51-freya-internal-audio" = {
    "context.objects" = [
      {
        factory = "adapter";
        args = {
          "factory.name" = "api.alsa.pcm.sink";
          "node.name" = "freya-laptop-speakers";
          "node.description" = "Laptop Speakers";
          "media.class" = "Audio/Sink";
          "api.alsa.path" = "hw:sofsoundwire,2";
          "audio.channels" = 2;
          "audio.position" = "FL,FR";
          "node.icon-name" = "audio-speakers";
          # The order suffix is required: bare `audioconvert.filter-graph` is only the
          # PropInfo entry and gets parsed then silently dropped. Wrapping the value in
          # a `filter.graph` key fails with "unexpected graph key".
          "audioconvert.filter-graph.0" = builtins.toJSON filterGraph;
        };
      }
      {
        factory = "adapter";
        args = {
          "factory.name" = "api.alsa.pcm.source";
          "node.name" = "freya-laptop-mic";
          "node.description" = "Laptop Microphone";
          "media.class" = "Audio/Source";
          "api.alsa.path" = "hw:sofsoundwire,10";
          "audio.channels" = 2;
          "audio.position" = "FL,FR";
          "node.icon-name" = "audio-input-microphone";
        };
      }
    ];
  };

  # Both default names come from the PCI product string ("Core Ultra Processors
  # (Series 3) HD Audio"); the sink is in fact only the headphone jack.
  services.pipewire.wireplumber.extraConfig."52-freya-audio-names" = {
    "monitor.alsa.rules" = [
      {
        matches = [{"device.name" = "alsa_card.pci-0000_00_1f.3-platform-sof_sdw";}];
        actions.update-props = {
          "device.description" = "Internal Audio";
          "device.nick" = "Internal Audio";
        };
      }
      {
        matches = [{"node.name" = "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.stereo-fallback";}];
        actions.update-props = {
          "node.description" = "Headphone Jack";
          "node.nick" = "Headphone Jack";
        };
      }
    ];
  };

  systemd.services.freya-audio-switches = {
    description = "Enable RT1320 speaker amp + DMIC (no kernel machine driver)";
    wantedBy = ["multi-user.target"];
    after = ["sound.target"];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "freya-audio-switches" ''
        # SoundWire controls enumerate some time after sound.target.
        for _ in $(seq 1 30); do
          ${amixer} -c sofsoundwire cget name="Dmic0 Capture Switch" >/dev/null 2>&1 && break
          sleep 1
        done
        ${setOn}
      '';
    };
  };

  # The card drops these switches across suspend/resume.
  powerManagement.resumeCommands = lib.concatMapStringsSep "\n" (c: ''${amixer} -c sofsoundwire cset name="${c}" on || true'') controls;
}
