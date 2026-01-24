_: {
  # sound.enable = true; #deprecated in 24.11 TODO remove this line when 24.11 release
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
    wireplumber.extraConfig.bluetoothEnhancements = {
      "monitor.bluez.properties" = {
        ## Maximize sample rate for best quality (up from default 48000 Hz)
        ## Higher sample rate = better frequency response and detail
        "bluez5.default.rate" = 96000;
        "bluez5.default.channels" = 2;

        ## Enable SBC-XQ: high bitrate SBC codec (up to 730 kbps vs standard 345 kbps)
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;

        ## Define available profiles - removed headset profiles to prevent low-quality auto-connect
        ## Only enable A2DP for high-quality audio. Uncomment hfp/hsp if you need microphone support
        "bluez5.roles" = ["a2dp_sink" "a2dp_source"];

        ## Codec priority list: prefer high-quality codecs first
        ## Note: OpenRun Pro 2 only supports SBC, but this helps other devices
        "bluez5.codecs" = ["sbc_xq" "sbc" "aac" "ldac" "aptx" "aptx_hd"];

        ## LDAC quality setting (for devices that support it)
        ## Options: "auto" (adaptive), "hq" (990kbps), "sq" (660kbps), "mq" (330kbps)
        "bluez5.a2dp.ldac.quality" = "hq";

        ## AAC bitrate mode (for devices that support it)
        ## 0 = constant bitrate, 1-5 = quality levels (5 = highest)
        "bluez5.a2dp.aac.bitratemode" = 0;
      };
      ## Fix: Auto-connect A2DP profile when Bluetooth devices connect (prevents "off" profile issue)
      ## Documented at: https://pipewire.pages.freedesktop.org/wireplumber/daemon/configuration/bluetooth.html
      "monitor.bluez.rules" = [
        {
          matches = [
            {
              ## Match all bluez devices
              "device.name" = "~bluez_card.*";
            }
          ];
          actions = {
            update-props = {
              ## Auto-connect A2DP profile ONLY by default for best audio quality
              ## HFP (phone call mode) can be manually enabled when needed
              "bluez5.auto-connect" = ["a2dp_sink"];
            };
          };
        }
      ];
    };

    ## Optimize PipeWire audio processing for maximum quality
    extraConfig.pipewire."99-quality-settings" = {
      "context.properties" = {
        ## Use highest quality resampling algorithm
        ## Valid range: 0-14 (default is 4)
        ## Quality 10 = good balance, 14 = maximum quality (uses significantly more CPU)
        "resample.quality" = 14;

        ## Increase default sample rate to match bluetooth settings
        "default.clock.rate" = 96000;

        ## Reduce quantum (buffer size) for lower latency while maintaining quality
        ## 1024/96000 = ~10.7ms latency (good balance for bluetooth)
        "default.clock.quantum" = 1024;
        "default.clock.min-quantum" = 1024;
        "default.clock.max-quantum" = 2048;
      };
    };
  };
}
