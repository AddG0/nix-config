{optional, ...}: {
  macos.home = with optional.home.desktops.macos; [omniwm wallpaper-cycle];
}
