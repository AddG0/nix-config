{optional, ...}: {
  macos.home = with optional.home.desktops.macos; [omniwm skhd sol wallpaper-cycle wallpaper-picker];
}
