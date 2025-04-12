{
  config,
  lib,
  pkgs,
  ...
}: {
  # Enable Plasma desktop environment
  services.xserver = {
    enable = true;
    displayManager.sddm.enable = true;
    desktopManager.plasma5.enable = true;
  };

  # Plasma packages
  environment.plasma5.excludePackages = with pkgs.libsForQt5; [
    plasma-browser-integration
    konsole
    oxygen
  ];

  # Additional Plasma-related packages
  environment.systemPackages = with pkgs; [
    # Plasma utilities
    plasma5Packages.kdeplasma-addons
    plasma5Packages.kde-gtk-config
    plasma5Packages.khotkeys
    plasma5Packages.kmenuedit
    plasma5Packages.kscreen
    plasma5Packages.kwallet-pam
    plasma5Packages.kwayland-integration
    plasma5Packages.plasma-desktop
    plasma5Packages.plasma-workspace
    plasma5Packages.powerdevil
    plasma5Packages.systemsettings

    # Qt and GTK integration
    gsettings-desktop-schemas
    gtk3
    gtk4
    qt5.qtbase
    qt5.qtwayland
  ];

  # Enable PAM for KWallet
  security.pam.services.sddm.enableKwallet = true;

  # Enable XDG portal for screen sharing
  xdg.portal = {
    enable = true;
    extraPortals = [pkgs.kdePackages.xdg-desktop-portal-kde];
  };
}
