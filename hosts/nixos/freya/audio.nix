{
  lib,
  pkgs,
  ...
}: let
  # Controls the generic topology leaves off and manages for nobody.
  # Enabled at boot and re-applied on resume.
  controls = [
    "Speaker Switch" # speaker DAC path
    "rt1320-1 OT23 L Switch" # RT1320 amp left output terminal
    "rt1320-1 OT23 R Switch" # RT1320 amp right output terminal
    "Dmic0 Capture Switch" # built-in digital mic array
  ];
  amixer = "${pkgs.alsa-utils}/bin/amixer";
  setOn = lib.concatMapStringsSep "\n" (c: ''${amixer} -c sofsoundwire cset name="${c}" on'') controls;
in {
  # FLAKE-UPDATE: delete this whole module once the pinned kernel gains a
  # SoundWire machine driver for the RT721+RT1320 combo — then the speaker and
  # mic routes work natively. Re-check after a kernel bump: if `dmesg | grep -i
  # "No SoundWire machine driver"` is gone and real speaker/mic nodes appear,
  # remove.
  #
  # Razer Blade 16 (Panther Lake) internal audio — RT721 jack + RT1320 amp + DMIC.
  #
  # The kernel has no SoundWire machine driver for this codec combo, so it uses
  # the generic function-topology fallback: the only ACP sink opens hw:1,0 (the
  # headphone DAC), and the speaker amp (hw:1,2) and DMIC (hw:1,10) are never
  # exposed. All their enable/capture switches also sit off. Until a proper
  # machine driver / UCM lands upstream, wire them up by hand: dedicated PipeWire
  # nodes bound straight to the PCMs, plus a service that flips the switches on.

  # Dedicated sink + source on the free PCMs (ACP uses hw:1,0, HDMI hw:1,5-7).
  services.pipewire.extraConfig.pipewire."51-freya-internal-audio" = {
    "context.objects" = [
      {
        factory = "adapter";
        args = {
          "factory.name" = "api.alsa.pcm.sink";
          "node.name" = "freya-laptop-speakers";
          "node.description" = "Laptop Speakers";
          "media.class" = "Audio/Sink";
          "api.alsa.path" = "hw:1,2";
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
          "api.alsa.path" = "hw:1,10";
          "audio.channels" = 2;
          "audio.position" = "FL,FR";
          "node.icon-name" = "audio-input-microphone";
        };
      }
    ];
  };

  # The generic-topology fallback sink (hw:1,0, the headphone DAC) is named
  # "Panther Lake Smart Sound Technology BUS Stereo" by default. Relabel it.
  services.pipewire.wireplumber.extraConfig."52-freya-headphone-jack" = {
    "monitor.alsa.rules" = [
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
        # Wait for the SoundWire controls to appear after boot.
        for _ in $(seq 1 30); do
          ${amixer} -c sofsoundwire cget name="Dmic0 Capture Switch" >/dev/null 2>&1 && break
          sleep 1
        done
        ${setOn}
      '';
    };
  };

  # The card drops these switches across suspend/resume; re-apply on wake.
  powerManagement.resumeCommands = lib.concatMapStringsSep "\n" (c: ''${amixer} -c sofsoundwire cset name="${c}" on || true'') controls;
}
