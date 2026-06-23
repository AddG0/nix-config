{pkgs, ...}: {
  # DevTools dock cycle: Ctrl+Shift+D (right → bottom)
  # Flag references:
  #   https://wiki.archlinux.org/title/Chromium
  #   https://chromium.googlesource.com/chromium/src/+/refs/heads/main/docs/gpu/vaapi.md
  #   https://issues.chromium.org/issues/41198007
  programs.chromium = {
    enable = true;
    package = pkgs.chromium;
    commandLineArgs = [
      # Force native Wayland rendering instead of XWayland. Required as an
      # explicit flag from Chromium 124+ (Arch Wiki).
      "--ozone-platform=wayland"

      # Zen is the default browser — silence chromium's "set as default" nag.
      "--no-default-browser-check"

      # VaapiVideoDecodeLinuxGL: VA-API hardware video decode on Linux/Ozone.
      # WebRTCPipeWireCapturer: screen sharing via xdg-desktop-portal/PipeWire.
      # MiddleClickAutoscroll: Windows-style middle-click drag-to-scroll;
      # disabled by default on Linux release builds, this opts in.
      "--enable-features=VaapiVideoDecodeLinuxGL,WebRTCPipeWireCapturer,MiddleClickAutoscroll"

      # The chrome://flags toggle is broken (crbug 41198007); the CLI flag
      # is the working path to override conservative GPU blocklisting.
      "--ignore-gpu-blocklist"
    ];
    extensions = [
      # Stylix has a target but only on the nixos level, not through home manager
      # This extension though requires no runtime changes and just works
      {id = "bkkmolkhemgaeaeggcmfbghljjjoofoh";} # Catppuccin Mocha theme
      {id = "aeblfdkhhhdcdjpifhhbdiojplfjncoa";} # 1Password
      {id = "fmkadmapgofadopljbjfkapdkoienihi";} # React Developer Tools
      {id = "nhdogjmejiglipccpnnnanhbledajbpd";} # Vue.js devtools
      {id = "lmhkpmbekcpmknklioeibfkpmmfibljd";} # Redux DevTools
      {id = "bcjindcccaagfpapjjmafapmmgkkhgoa";} # JSON Formatter
      {id = "gppongmhjkpfnbhagpmjfkannrkvzykc";} # Wappalyzer
      {id = "lhdoppojpmngadmnindnejefpokejbdd";} # axe DevTools
      {id = "pgamkpjkbfldnmemhcbekimfdnjcgkco";} # Tailwind CSS DevTools
      {id = "cdockenadnadldjbbgcallicgledbeoc";} # VisBug (click-to-edit page editor)
      {id = "jabopobgcpjmedljpbcaablpmlmfcogm";} # WhatFont
      {id = "bhlhnicpbhignbdhedgjhgdocnmhomnp";} # ColorZilla (eyedropper + gradient gen)
    ];
  };
}
