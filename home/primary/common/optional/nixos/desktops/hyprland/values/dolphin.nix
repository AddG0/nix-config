{pkgs, ...}: {
  xdg.mimeApps = {
    defaultApplications = {
      "inode/directory" = "org.kde.dolphin.desktop";
    };
  };

  # Fix for empty "Open With" menu in Dolphin when running under Hyprland
  xdg.configFile."menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  home.packages = with pkgs; [
    # Dolphin and required dependencies
    kdePackages.dolphin
    kdePackages.kio
    kdePackages.kdf
    kdePackages.kio-fuse
    kdePackages.kio-extras
    kdePackages.kio-admin
    kdePackages.qtwayland
    kdePackages.plasma-integration
    kdePackages.kdegraphics-thumbnailers
    kdePackages.breeze-icons
    kdePackages.qtsvg
    kdePackages.kservice
    kdePackages.ffmpegthumbs # Video thumbnail support
    shared-mime-info

    # Additional KDE-specific packages
    kdePackages.kate
  ];
}
