{pkgs, ...}: {
  programs.steam = {
    enable = true;
    protontricks.enable = true;

    package = pkgs.steam.override {
      extraPkgs = pkgs: (builtins.attrValues {
        inherit
          (pkgs.stdenv.cc.cc)
          lib
          ;

        inherit
          (pkgs)
          libxcursor
          libxi
          libxinerama
          libxscrnsaver
          libpng
          libpulseaudio
          libvorbis
          libkrb5
          keyutils
          gperftools
          ;
      });

      # Move Steam's CEF debugger off 8080 (commonly used; leave it free);
      # decky-loader is patched to match in gaming/decky.nix.
      extraArgs = "-devtools-port 21379";
    };

    extraCompatPackages = [
      pkgs.proton-ge-bin
      pkgs.proton-cachyos
    ];
  };
}
