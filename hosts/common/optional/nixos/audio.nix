_: {
  services.pulseaudio.enable = false;
  security.rtkit.enable = true;
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    alsa.support32Bit = true;
    pulse.enable = true;
    wireplumber.enable = true;
    jack.enable = true;

    # use the example session manager (no others are packaged yet so this is enabled by default,
    # no need to redefine it in your config for now)
    # media-session.enable = true;

    # Enable high-quality Bluetooth audio codecs
    wireplumber.extraConfig."10-bluez" = {
      "monitor.bluez.properties" = {
        ## Enable SBC-XQ: high bitrate SBC codec (up to 730 kbps vs standard 345 kbps)
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;

        ## Use native HFP/HSP backend (most reliable with PipeWire)
        "bluez5.hfphsp-backend" = "native";

        ## Enable A2DP and HFP roles (HSP excluded — some headsets including
        ## AirPods don't work with both HSP and HFP enabled simultaneously)
        "bluez5.roles" = [
          "a2dp_sink"
          "a2dp_source"
          "hfp_hf"
          "hfp_ag"
        ];

        ## Only auto-connect A2DP — HFP connects on-demand when a mic input
        ## stream is detected. Prevents the HFP retry loop that blocks A2DP
        ## and causes repeated disconnects with AirPods.
        "bluez5.auto-connect" = [
          "a2dp_sink"
          "a2dp_source"
        ];
      };
    };

    ## Optimize PipeWire audio processing for maximum quality
    extraConfig.pipewire."99-quality-settings" = {
      "context.properties" = {
        ## Use highest quality resampling algorithm
        ## Valid range: 0-14 (default is 4)
        ## Quality 10 = good balance, 14 = maximum quality (uses significantly more CPU)
        "resample.quality" = 14;

        ## Reduce quantum (buffer size) for lower latency while maintaining quality
        ## 1024 frames gives a good latency / stability tradeoff
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 1024;
        "default.clock.max-quantum" = 2048;
      };
    };
  };
}
