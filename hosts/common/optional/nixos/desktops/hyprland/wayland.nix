{pkgs, ...}: {
  # general packages related to wayland
  environment.systemPackages = [
    pkgs.waypaper # wayland packages(nitrogen analog for wayland)
    pkgs.awww # backend wallpaper daemon required by waypaper
  ];
}
