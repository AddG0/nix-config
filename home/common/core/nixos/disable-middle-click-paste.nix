_: let
  # Collides with middle-drag pan in canvas apps like Figma; Hyprland's
  # misc:middle_click_paste doesn't reach Chromium (hyprwm/Hyprland#12299).
  disablePrimaryPaste.gtk-enable-primary-paste = false;
in {
  gtk = {
    gtk3.extraConfig = disablePrimaryPaste;
    gtk4.extraConfig = disablePrimaryPaste;
  };
}
