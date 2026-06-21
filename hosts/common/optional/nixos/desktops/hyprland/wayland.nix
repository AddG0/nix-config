{pkgs, ...}: {
  # general packages related to wayland
  environment.systemPackages = [
    pkgs.waypaper # wayland packages(nitrogen analog for wayland)
    pkgs.awww # backend wallpaper daemon required by waypaper
    pkgs.wl-clipboard # Command-line copy/paste utilities for Wayland
  ];
}
