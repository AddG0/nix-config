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

  dolphinDeps = with pkgs.kdePackages; [
    kio
    kdf
    kio-fuse
    kio-extras
    kio-admin
    qtwayland
    plasma-integration
    kdegraphics-thumbnailers
    breeze-icons
    qtsvg
    kservice
    ffmpegthumbs
    qtmultimedia
    ark
  ];

  wrappedDolphin = pkgs.symlinkJoin {
    name = "dolphin-wrapped";
    paths = [pkgs.kdePackages.dolphin] ++ dolphinDeps;
    buildInputs = [pkgs.makeWrapper];
    postBuild = let
      qtPluginPaths = builtins.concatStringsSep ":" (map (p: "${p}/lib/qt-6/plugins") dolphinDeps);
      dataDirs = builtins.concatStringsSep ":" (map (p: "${p}/share") ([pkgs.shared-mime-info] ++ dolphinDeps));
    in ''
      for exe in $out/bin/dolphin; do
        wrapProgram "$exe" \
          --prefix QT_PLUGIN_PATH : "${qtPluginPaths}" \
          --prefix XDG_DATA_DIRS : "${dataDirs}" \
          --prefix LD_LIBRARY_PATH : "${pkgs.pipewire}/lib"
      done
    '';
  };
in {
  # 1) Make Dolphin your default file manager
  xdg.mimeApps = {
    defaultApplications = {
      "inode/directory" = "org.kde.dolphin.desktop";
    };
  };

  # 2) Fix for empty "Open With" menu under Hyprland
  xdg.configFile."menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  # 3) Drop in our "Extract Here" service menu
  xdg.configFile."kservices5/ServiceMenus/extracthere.desktop".text = extractHereDesktop;

  xdg.configFile."dolphinrc".text = ''
    [UiSettings]
    ColorScheme=*

    [PreviewSettings]
    Plugins=appimagethumbnail,audiothumbnail,blenderthumbnail,comicbookthumbnail,cursorthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,directorythumbnail,fontthumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,windowsexethumbnail,windowsimagethumbnail,mobithumbnail,opendocumentthumbnail,gsthumbnail,rawthumbnail,svgthumbnail,ffmpegthumbs
    EnableRemoteFolderThumbnail=true
    MaximumSize=21474836480
    MaximumRemoteSize=21474836480
  '';

  home.packages = [wrappedDolphin];
}
