{lib, ...}: {
  imports = lib.custom.scanPaths ./.;

  programs.hyprland = {
    enable = true;
  };

  services.dbus.enable = true;

  # Allow file managers to discover plugged in devices
  services.udisks2.enable = lib.mkDefault true;

  services.greetd.sessionCommand = lib.mkDefault "Hyprland";
}
