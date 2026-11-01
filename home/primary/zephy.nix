{lib, ...}: {
  imports = lib.flatten [
    (with lib.custom.optional.home; [browsers comms ghostty librepods])
    (with lib.custom.optional.home.gaming; [heroic minecraft r2modman rocket-league])
    (with lib.custom.optional.home.media; [core spicetify vlc])
    (with lib.custom.optional.primary; [stylix])
    (with lib.custom.optional.primary.secrets; [onepassword-ssh])
  ];

  desktops.defaultSession = "hyprland";

  # The connector, not desc:, since recovery.nix passes the monitor to hyprctl unquoted.
  wayland.windowManager.hyprland.settings.workspace = ["3, monitor:DP-3, default:true"];

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
