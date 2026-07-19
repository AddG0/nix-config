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
    };

    extraCompatPackages = [
      pkgs.proton-ge-bin
      pkgs.proton-cachyos
    ];
  };
}
