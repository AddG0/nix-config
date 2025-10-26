{
  config,
  lib,
  ...
}:
with lib; let
  cfg = config.modules.desktop.hyprland;
in {
  options.modules.desktop.hyprland = {
    nvidia = mkEnableOption "whether nvidia GPU is used";
  };

  # config = mkIf (cfg.enable && cfg.nvidia) {
  #   wayland.windowManager.hyprland.settings.env = [
  #     # for hyprland with nvidia gpu, ref https://wiki.hyprland.org/Nvidia/
  #     "LIBVA_DRIVER_NAME,nvidia"
  #     "XDG_SESSION_TYPE,wayland"
  #     "GBM_BACKEND,nvidia-drm"
  #     "AQ_DRM_DEVICES,/dev/dri/card1"
  #     "__GLX_VENDOR_LIBRARY_NAME,nvidia"
  #     # fix https://github.com/hyprwm/Hyprland/issues/1520
  #     "WLR_NO_HARDWARE_CURSORS,1"
  #   ];
  # };

  config = mkIf (cfg.enable && cfg.nvidia) {
    wayland.windowManager.hyprland.settings.env = [
      # for hyprland with nvidia gpu, ref https://wiki.hyprland.org/Nvidia/
      "LIBVA_DRIVER_NAME,nvidia"
      "XDG_SESSION_TYPE,wayland"
      "GBM_BACKEND,nvidia-drm"
      # Dynamically find available DRI devices
      "AQ_DRM_DEVICES,${
        if builtins.pathExists "/dev/dri"
        then builtins.concatStringsSep ":" (map (card: "/dev/dri/${card}") (builtins.attrNames (builtins.readDir "/dev/dri")))
        else "/dev/dri/card0"
      }"
      "__GLX_VENDOR_LIBRARY_NAME,nvidia"

      # Optional: Enable additional NVIDIA settings for Hyprland, based on your configuration
      "NVIDIA_DISABLE_DRI3=1" # Disables DRI3, might help with some graphical glitches
      "LIBGL_ALWAYS_INDIRECT=1" # Forces indirect rendering (helpful in some setups)
    ];
  };
}
