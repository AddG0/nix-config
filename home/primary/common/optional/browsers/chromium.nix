{
  config,
  pkgs,
  ...
}: {
  programs.chromium = {
    enable = true;
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
    ];
  };


  xdg.mimeApps = {
    defaultApplications = {
      "text/html" = "chromium.desktop";
      "x-scheme-handler/http" = "chromium.desktop";
      "x-scheme-handler/https" = "chromium.desktop";
    };
  };
}
