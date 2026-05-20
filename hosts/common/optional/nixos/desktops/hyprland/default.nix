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
  # Have hyprlock release the keyring on unlock, mirroring greetd at login.
  # Without this the keyring stays locked across screen lock cycles and any
  # app holding a secret (1Password, network secrets, etc.) silently fails
  # until the user opens seahorse to type the password again.
  #   https://discourse.nixos.org/t/automatically-unlock-gnome-keyring-with-hyprlock/54166
  security.pam.services.hyprlock.enableGnomeKeyring = true;
}
