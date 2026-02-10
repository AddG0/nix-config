{lib, ...}: {
  # Hide the macOS menu bar (sketchybar replaces it)
  # Requires logout/reboot to take effect on macOS 15+
  system.defaults.NSGlobalDomain._HIHideMenuBar = lib.mkForce true;
}
