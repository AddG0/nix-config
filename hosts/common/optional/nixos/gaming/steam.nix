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

      # Everything that connects to the debugger is retargeted to match in
      # overlays/common/gaming/steam-devtools-port.nix.
      extraArgs = "-devtools-port 21379";
    };

    # No extraCompatPackages: it would bake a collectable store path into every
    # Proton prefix. The gaming home module installs the tools instead.
  };
}
