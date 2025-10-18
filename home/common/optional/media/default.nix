{pkgs, ...}: {
  home.packages = builtins.attrValues {
    inherit
      (pkgs)
      ffmpeg
      vlc
      losslesscut
      ;
    inherit
      (pkgs.stable)
      calibre
      ;
  };
}
