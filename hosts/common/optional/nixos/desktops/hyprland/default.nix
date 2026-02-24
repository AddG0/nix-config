{
  lib,
  config,
  ...
}: {
  imports = lib.custom.scanPaths ./.;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  services.greetd.sessionCommand = "uwsm start hyprland-uwsm.desktop";

  services.dbus.enable = true;

  # Allow file managers to discover plugged in devices
  services.udisks2.enable = lib.mkDefault true;

  # Credential store (replaces kwallet for non-Plasma sessions)
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = lib.mkIf config.services.greetd.enable true;
}
