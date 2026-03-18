{pkgs, ...}: {
  imports = [
    ./settings.nix
    ./binds.nix
    ./plugins
    ./apps
  ];

  # wayland session entry for greetd
  home.file.".wayland-session" = {
    source = "${pkgs.hyprland}/bin/Hyprland";
    executable = true;
  };

  services.hyprpolkitagent.enable = true;

  # Provides org.gnome.keyring.SystemPrompter D-Bus service.
  # Without it, apps like 1Password fail to store credentials:
  # "The name org.gnome.keyring.SystemPrompter was not provided by any .service files"
  # gnome-keyring itself is started via PAM (see nixos/desktops/hyprland)
  home.packages = [pkgs.gcr];
}
