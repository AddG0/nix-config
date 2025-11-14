{pkgs, ...}: {
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
        "bluez5.enable-sbc-xq" = true;
        "bluez5.enable-msbc" = true;
        "bluez5.enable-hw-volume" = true;
        "bluez5.roles" = ["a2dp_sink" "a2dp_source" "hsp_hs" "hsp_ag" "hfp_hf" "hfp_ag"];
      };
    };
  };

  environment.systemPackages = [
    pkgs.playerctl # cli utility and lib for controlling media players
    # pkgs.pamixer # cli pulseaudio sound mixer
  ];
}