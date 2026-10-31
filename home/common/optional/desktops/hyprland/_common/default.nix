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

  desktops.defaultSession = lib.mkDefault "hyprland";

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

  lib.hyprland = let
    # UWSM names it after the desktop ID; the hyprland-uwsm session starts hyprland.desktop.
    sessionUnit = "wayland-wm@hyprland.desktop.service";
  in {
    inherit sessionUnit;
    # Re-binds a unit to Hyprland alone, e.g. hyprpolkitagent: HM puts it on the kit target, and niri brings its own agent.
    startWithHyprland = {
      Install.WantedBy = lib.mkForce [sessionUnit];
      Unit.PartOf = lib.mkForce [sessionUnit];
    };
  };

  systemd.user.targets.bare-compositor-session.Install.WantedBy = [config.lib.hyprland.sessionUnit];
  systemd.user.services.hyprpolkitagent = config.lib.hyprland.startWithHyprland;

  services.hyprpolkitagent.enable = true;

  # Provides org.gnome.keyring.SystemPrompter D-Bus service.
  # Without it, apps like 1Password fail to store credentials:
  # "The name org.gnome.keyring.SystemPrompter was not provided by any .service files"
  # gnome-keyring itself is started via PAM (see nixos/desktops/hyprland)
  home.packages = [pkgs.gcr_3];
}
