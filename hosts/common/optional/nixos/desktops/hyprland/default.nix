{
  inputs,
  lib,
  config,
  pkgs,
  ...
}: let
  # Same nixpkgs the hyprland-hy3 overlay's Hyprland is built from.
  hyprlandPkgs = inputs.hy3.inputs.hyprland.inputs.nixpkgs.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in {
  imports = lib.custom.scanPaths ./.;

  programs.hyprland = {
    enable = true;
    withUWSM = true;
  };

  # nixpkgs sets this with mkDefault, so another desktop's plain definition would drop Hyprland's portals.conf.
  xdg.portal.configPackages = [config.programs.hyprland.package];

  # Hyprland loads /run/opengl-driver Mesa into its own glibc; a newer system Mesa aborts it at startup.
  hardware.graphics = {
    package = hyprlandPkgs.mesa;
    package32 = hyprlandPkgs.pkgsi686Linux.mesa;
  };

  # Hyprland comes from upstream's flake (via hy3), which this cache builds.
  nix.settings = {
    substituters = ["https://hyprland.cachix.org"];
    trusted-public-keys = ["hyprland.cachix.org-1:a7pgxzMz7+chwVL3/pzj6jIBMioiJM7ypFP8PwtkuGc="];
  };

  desktops.sessions = {
    hyprland = {
      sessionName = "hyprland-uwsm";
      displayName = "Hyprland";
      desktopNames = ["Hyprland"];
      command = "uwsm start -e -D Hyprland hyprland.desktop";
      stop = "uwsm stop";
    };
    # The entry `uwsm start` above launches; kept off greeter lists, where it would skip uwsm and Gaming Mode.
    hyprland-compositor = {
      sessionName = "hyprland";
      displayName = "Hyprland";
      desktopNames = ["Hyprland"];
      command = lib.getExe' config.programs.hyprland.package "start-hyprland";
      noDisplay = true;
    };
  };

  services.dbus.enable = true;

  # Allow file managers to discover plugged in devices
  services.udisks2.enable = lib.mkDefault true;

  # Credential store (replaces kwallet for non-Plasma sessions)
  services.gnome.gnome-keyring.enable = true;
  # The keyring drags gcr's agent in, which set-environments over 1Password for non-shell apps.
  services.gnome.gcr-ssh-agent.enable = false;
  security.pam.services.greetd.enableGnomeKeyring = lib.mkIf config.services.greetd.enable true;
  # Have hyprlock release the keyring on unlock, mirroring greetd at login.
  # Without this the keyring stays locked across screen lock cycles and any
  # app holding a secret (1Password, network secrets, etc.) silently fails
  # until the user opens seahorse to type the password again.
  #   https://discourse.nixos.org/t/automatically-unlock-gnome-keyring-with-hyprlock/54166
  security.pam.services.hyprlock.enableGnomeKeyring = true;
}
