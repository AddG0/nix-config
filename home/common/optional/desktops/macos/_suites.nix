{optional, ...}: {
  macos.home = with optional.home.desktops.macos; [omniwm sol wallpaper-cycle];
}
