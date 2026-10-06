{lib, ...}: {
  imports = lib.flatten [
    # lib.custom.suites.virtualization.home
    lib.custom.suites.development.home
    lib.custom.suites.ai.home
    (with lib.custom.optional.home; [browsers comms ghostty helper-scripts librepods])
    (with lib.custom.optional.home.desktops; [
      # hyprland.nvidia
      # hyprland.personal
      # hyprland.sunshine
    ])
    (with lib.custom.optional.home.development; [
      aws
      gcloud
      grpc
      ide.jetbrains-remote
      ide.vscode-server
      jupyter-notebook
      postman
      terraform
      virtualization.kubernetes
      virtualization.lens
      virtualization.nixos-shell
    ])
    (with lib.custom.optional.home.gaming; [heroic minecraft r2modman rocket-league])
    (with lib.custom.optional.home.media; [
      core
      spicetify
      # tidal
      vlc
    ])
    (with lib.custom.optional.home.remote-desktop; [
      # mouseshare.lan-mouse
      # rustdesk
    ])
    (with lib.custom.optional.home.secrets; [ai buf sops elevenlabs kubeconfig])
    (with lib.custom.optional.home.tools; [wayscriber])
    (with lib.custom.optional.primary; [stylix work])
    (with lib.custom.optional.primary.development; [aws])
    (with lib.custom.optional.primary.secrets; [onepassword-ssh])
  ];

  # Doesn't work on plasma saddly
  stylix.enable = lib.mkForce false;

  # programs.plasma.input.mice = [
  #   {
  #     enable = true;
  #     name = "ASUE140F:00 04F3:31F7 Mouse";
  #     vendorId = "04F3";
  #     productId = "31F7";
  #     accelerationProfile = "none";
  #     naturalScroll = false;
  #     scrollSpeed = 0.2;
  #   }
  # ];

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
      output = "desc:AU Optronics 0x8E9D";
      width = 2560;
      height = 1600;
      refreshRate = 165;
      x = 555;
      y = 0;
      vrr = "on";
      primary = true;
      bitdepth = 10;
    }
    {
      output = "desc:BOE 0x0A68";
      width = 3840;
      height = 1100;
      refreshRate = 60;
      x = 0;
      y = 1600;
    }
  ];
}
