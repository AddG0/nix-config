{
  config,
  inputs,
  pkgs,
  lib,
  ...
}: {
  imports = lib.flatten [
    # lib.custom.suites.ai.home
    # lib.custom.suites.virtualization.home
    lib.custom.suites.ide.home
    (with lib.custom.optional.home; [browsers comms ghostty helper-scripts])
    (with lib.custom.optional.home.development; [
      gcloud
      # jupyter-notebook
      postman
      # virtualization.lens
    ])
    (with lib.custom.optional.home.gaming; [heroic minecraft])
    (with lib.custom.optional.home.media; [core spicetify tidal vlc])
    (with lib.custom.optional.home.remote-desktop; [
      # mouseshare.lan-mouse
      # rustdesk
    ])
    (with lib.custom.optional.home.secrets; [
      # sops
      # kubeconfig
    ])
    (with lib.custom.optional.home.services; [safeeyes])
  ];

  home.file."Videos/Movies".source = config.lib.file.mkOutOfStoreSymlink "/mnt/videos";

  stylix = {
    enable = false;
    image = pkgs.fetchurl {
      url = "https://unsplash.com/photos/3l3RwQdHRHg/download?ixid=M3wxMjA3fDB8MXxhbGx8fHx8fHx8fHwxNzM2NTE4NDQ2fA&force=true";
      sha256 = "LtdnBAxruHKYE/NycsA614lL6qbGBlkrlj3EPNZ/phU=";
    };
    base16Scheme = "${inputs.tt-schemes}/base16/catppuccin-mocha.yaml";
    cursor = {
      package = pkgs.bibata-cursors;
      name = "Bibata-Original-Classic";
      size = 24; # adjust to your display
    };
    opacity = {
      applications = 1.0;
      terminal = 1.0;
      desktop = 1.0;
      popups = 0.8;
    };
    polarity = "dark";
  };

  #
  # ========== Host-specific Monitor Spec ==========
  #
  # This uses the nix-config/modules/home/montiors.nix module which defaults to enabled.
  # Your nix-config/home-manger/<user>/common/optional/desktops/foo.nix WM config should parse and apply these values to it's monitor settings
  # If on hyprland, use `hyprctl monitors` to get monitor info.
  # https://wiki.hyprland.org/Configuring/Monitors/
  #           ------
  #        | HDMI-A-1 |
  #           ------
  #  ------   ------   ------
  # | DP-2 | | DP-1 | | DP-3 |
  #  ------   ------   ------
  display.monitors = [
    {
      output = "DP-1";
      width = 3440;
      height = 1440;
      refreshRate = 180;
      x = 3840;
      y = 218;
      vrr = "on";
      primary = true;
    }
    {
      output = "DP-2";
      width = 3840;
      height = 2160;
      refreshRate = 144;
      x = 0;
      y = 0;
    }
    {
      output = "DP-3";
      width = 1920;
      height = 1080;
      refreshRate = 60;
      transform = "270";
      x = 7280;
      y = 0;
    }
  ];
}
