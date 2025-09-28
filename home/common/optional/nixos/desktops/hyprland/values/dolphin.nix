{pkgs, ...}: let
  extractHereDesktop = ''
    [Desktop Entry]
    Type=Service
    X-KDE-ServiceTypes=KonqPopupMenu/Plugin
    MimeType=application/zip;application/x-tar;application/x-bzip-compressed-tar;application/x-gzip;application/x-xz;application/x-7z-compressed;
    Actions=extractHere
    X-KDE-Priority=TopLevel

    [Desktop Action extractHere]
    Name=Extract Here
    Icon=package-extract
    Exec=ark --batch --extract "%F" "%D"
  '';
in {
  # 1) Make Dolphin your default file manager
  xdg.mimeApps = {
    defaultApplications = {
      "inode/directory" = "org.kde.dolphin.desktop";
    };
  };

  # 2) Fix for empty "Open With" menu under Hyprland
  xdg.configFile."menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  # 3) Drop in our “Extract Here” service menu
  xdg.configFile."kservices5/ServiceMenus/extracthere.desktop".text = extractHereDesktop;

  home.packages = with pkgs; [
    # Dolphin and its friends
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
    kdePackages.ffmpegthumbs
    shared-mime-info

    # For editing text
    kdePackages.kate

    # <-- add Ark so we can extract archives
    kdePackages.ark
  ];
}
