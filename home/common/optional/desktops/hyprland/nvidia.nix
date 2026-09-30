_: {
  wayland.windowManager.hyprland.settings = {
    env = [
      "LIBVA_DRIVER_NAME,nvidia"
      "XDG_SESSION_TYPE,wayland"
      "GBM_BACKEND,nvidia-drm"
      "__GLX_VENDOR_LIBRARY_NAME,nvidia"
    ];

    # Replaces the legacy WLR_NO_HARDWARE_CURSORS env var, which Aquamarine
    # (Hyprland's post-wlroots renderer) no longer honors. Also lets the
    # hyprsunset CTM dim the cursor along with the rest of the screen.
    cursor.no_hardware_cursors = true;
  };
}
