_: {
  programs.chromium = {
    enable = false;
    # commandLineArgs = [
    #   "--ignore-gpu-blocklist"
    #   "--enable-gpu-rasterization"
    #   "--enable-zero-copy"
    #   "--enable-features=VaapiVideoDecoder,CanvasOopRasterization,UseOzonePlatform,WebRTCPipeWireCapturer"
    #   "--ozone-platform=wayland"
    #   "--use-gl=desktop"
    # ];
    extensions = [
      {id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa";} # 1password
      {id = "aefkmifgmaafnojlojpnekbpbmjiiogg";} # Popup Blocker (strict)
      {id = "kdbmhfkmnlmbkgbabkdealhhbfhlmmon";} # SteamDB
      {id = "alageihdeogmjlkgifaeefodfbdbljjf";} # Youtube Auto Quality
    ];
  };

  nixpkgs.config.chromium.enableWideVine = true;
}
