{pkgs, ...}: {
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

  nixpkgs.config.chromium.enableWidevine = true;

  home.packages = [
    # https://www.reddit.com/r/kde/comments/1gjcfpp/window_title_bar_not_fully_maximizing_and_or/
    # chrome://flags enable ozone platform wayland to fix window title bar glitch
    pkgs.google-chrome
  ];
}
