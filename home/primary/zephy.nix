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
}
