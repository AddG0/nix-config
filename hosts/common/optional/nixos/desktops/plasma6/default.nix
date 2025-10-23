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

  services.greetd.sessionCommand = lib.mkDefault "${pkgs.kdePackages.plasma-workspace}/bin/startplasma-wayland";

  security.pam.services = {
    sddm.kwallet.enable = lib.mkIf config.services.displayManager.sddm.enable true;
    greetd.kwallet.enable = lib.mkIf config.services.greetd.enable true;
    kscreenlocker.kwallet.enable = lib.mkIf config.services.desktopManager.plasma6.enable true;
  };

  environment.systemPackages = with pkgs; [
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
    kdePackages.xwaylandvideobridge # Wayland video bridge for X11
    kdePackages.spectacle # Screenshot tool
  ];
}
