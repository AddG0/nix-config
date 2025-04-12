{pkgs, ...}: {
  xdg.mimeApps = {
    defaultApplications = {
      "inode/directory" = "org.kde.dolphin.desktop";
    };
  };

  home.packages = with pkgs; [
    kdePackages.dolphin
    kdePackages.qtwayland # Wayland support
    kdePackages.qtsvg # SVG icon support
    kdePackages.kio-fuse # Mount remote filesystems via FUSE
    kdePackages.kio-extras # Extra protocols support (sftp, fish etc)
    kdePackages.ffmpegthumbs # Thumbnail support
    kdePackages.kio-extras-kf5 # Additional KIO protocols
    kdePackages.kdegraphics-thumbnailers # Additional thumbnail support
    kdePackages.solid
    udisks2 # For disk management
  ];
}
