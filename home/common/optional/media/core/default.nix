{pkgs, ...}: {
  imports = [./vlc.nix];

  home.packages = [pkgs.ffmpeg];
}
