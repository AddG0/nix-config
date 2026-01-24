_: {
  # ============================================================================
  # Core Audio Configuration
  # ============================================================================
  # Base PipeWire/WirePlumber setup with high-fidelity audio settings
  # and real-time audio priority for the audio group.
  # ============================================================================

  # Grant audio group real-time priority and unlimited memory lock for low-latency audio
  security.pam.loginLimits = [
    {
      domain = "@audio";
      type = "soft";
      item = "rtprio";
      value = "95";
    }
    {
      domain = "@audio";
      type = "hard";
      item = "rtprio";
      value = "99";
    }
    {
      domain = "@audio";
      type = "soft";
      item = "memlock";
      value = "unlimited";
    }
    {
      domain = "@audio";
      type = "hard";
      item = "memlock";
      value = "unlimited";
    }
  ];

  security.rtkit.enable = true;

  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;

    extraConfig.pipewire = {
      # High-fidelity audio: Pass native sample rates to Hugo TT2
      # Let the DAC's WTA filter handle upsampling (Chord's specialty)
      "99-hifi.conf" = {
        "context.properties" = {
          "default.clock.rate" = 96000;
          "default.clock.allowed-rates" = [44100 48000 88200 96000 176400 192000];
          "default.clock.force-rate" = 96000; # Force 96kHz regardless of stream requests
          "resample.quality" = 14;
        };
      };
    };
  };
}
