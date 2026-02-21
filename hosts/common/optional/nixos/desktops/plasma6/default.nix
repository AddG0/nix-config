{
  config,
  lib,
  pkgs,
  ...
}: {
  services = {
    desktopManager.plasma6.enable = true;

    displayManager.sddm.enable = true;

    displayManager.sddm.wayland.enable = true;
    # xserver.enable = true;
  };

  security.pam.services = {
    sddm.kwallet.enable = lib.mkIf config.services.displayManager.sddm.enable true;
    greetd.kwallet = lib.mkIf config.services.greetd.enable {
      enable = true;
      forceRun = true; # Required for greetd since it's not detected as a graphical session
    };
    kscreenlocker.kwallet.enable = lib.mkIf config.services.desktopManager.plasma6.enable true;
  };

  environment.plasma6.excludePackages = with pkgs.kdePackages; [
    kate
  ];

  environment.systemPackages = with pkgs; [
    # Fix for "Could not register app ID: App info not found for 'org.kde.kioclient'"
    # See: https://bugs.kde.org/show_bug.cgi?id=512650
    (writeTextDir "share/applications/org.kde.kioclient.desktop" ''
      [Desktop Entry]
      Name=KDE Kioclient (compat)
      Exec=kioclient %u
      Type=Application
      NoDisplay=true
    '')
    kdePackages.kcalc # Calculator
    kdePackages.kcharselect # Tool to select and copy special characters from all installed fonts
    kdePackages.kcolorchooser # A small utility to select a color
    kdePackages.kolourpaint # Easy-to-use paint program
    kdePackages.ksystemlog # KDE SystemLog Application
    kdePackages.sddm-kcm # Configuration module for SDDM
    kdiff3 # Compares and merges 2 or 3 files or directories
    kdePackages.isoimagewriter # Optional: Program to write hybrid ISO files onto USB disks
    kdePackages.partitionmanager # Optional Manage the disk devices, partitions and file systems on your computer
    hardinfo2 # System information and benchmarks for Linux systems
    wayland-utils # Wayland utilities
    wl-clipboard # Command-line copy/paste utilities for Wayland
    kdePackages.spectacle # Screenshot tool
    kdePackages.plasma-nm # NetworkManager integration for Plasma (includes captive portal handler)
  ];
}
