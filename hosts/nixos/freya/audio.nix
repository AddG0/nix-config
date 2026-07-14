_: {
  # Razer Blade 16 (Panther Lake) internal audio — RT721 jack + RT1320 amp + DMIC.
  # No kernel machine driver, so the card runs the generic SoundWire UCM fallback,
  # which labels the nodes with verbose "HD Audio ..." names; rename them.
  services.pipewire.wireplumber.extraConfig."52-freya-audio-labels" = {
    "monitor.alsa.rules" = [
      {
        matches = [{"node.name" = "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Speaker__sink";}];
        actions.update-props = {
          "node.description" = "Laptop Speakers";
          "node.nick" = "Laptop Speakers";
        };
      }
      {
        matches = [{"node.name" = "alsa_output.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Headphones__sink";}];
        actions.update-props = {
          "node.description" = "Headphone Jack";
          "node.nick" = "Headphone Jack";
        };
      }
      {
        matches = [{"node.name" = "alsa_input.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Mic__source";}];
        actions.update-props = {
          "node.description" = "Laptop Microphone";
          "node.nick" = "Laptop Microphone";
        };
      }
      {
        matches = [{"node.name" = "alsa_input.pci-0000_00_1f.3-platform-sof_sdw.HiFi__Headset__source";}];
        actions.update-props = {
          "node.description" = "Headset Microphone";
          "node.nick" = "Headset Microphone";
        };
      }
    ];
  };
}
