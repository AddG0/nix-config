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
