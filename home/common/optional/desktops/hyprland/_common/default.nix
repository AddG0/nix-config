{
  config,
  lib,
  pkgs,
  ...
}: {
  imports = [
    ../../common
    ../../common/wayland-wm
    ./settings.nix
    ./binds.nix
    ./screenshots.nix
    ./plugins
    ./nwg-displays.nix
    ./pip.nix
    ./btop.nix
    ./monitor-control.nix
    ./recovery.nix
  ];

  # wayland session entry for greetd
  home.file.".wayland-session" = {
    source = "${pkgs.hyprland}/bin/Hyprland";
    executable = true;
  };

  desktop.session.dpms.Hyprland = let
    hyprctl = lib.getExe' config.wayland.windowManager.hyprland.package "hyprctl";
  in {
    off = "${hyprctl} dispatch dpms off";
    on = "${hyprctl} dispatch dpms on";
  };

  services.hyprpolkitagent.enable = true;

  # Provides org.gnome.keyring.SystemPrompter D-Bus service.
  # Without it, apps like 1Password fail to store credentials:
  # "The name org.gnome.keyring.SystemPrompter was not provided by any .service files"
  # gnome-keyring itself is started via PAM (see nixos/desktops/hyprland)
  home.packages = [pkgs.gcr_3];
}
