{pkgs, ...}: let
  package = pkgs.hyprland;
in {
  imports = [
    ./settings.nix
    ./binds.nix
    ./plugins
    ./noctalia.nix
    ./anyrun.nix
    ./apps
  ];

  # wayland session entry for greetd
  home.file.".wayland-session" = {
    source = "${package}/bin/Hyprland";
    executable = true;
  };

  # Credential store
  services.gnome-keyring = {
    enable = true;
    components = ["secrets"];
  };

  # Provides org.gnome.keyring.SystemPrompter D-Bus service.
  # Without it, apps like 1Password fail to store credentials:
  # "The name org.gnome.keyring.SystemPrompter was not provided by any .service files"
  home.packages = [pkgs.gcr];
}
