{
  pkgs,
  config,
  lib,
  ...
}: let
  home = config.home.homeDirectory;

  # Re-asserted on every rebuild, so Dolphin can't persist GUI reordering of the
  # Places sidebar. No plasma-manager option for it yet
  # (nix-community/plasma-manager#330), hence the hand-built XBEL.
  places = [
    {
      title = "Home";
      href = "file://${home}";
      icon = "user-home";
      system = true;
    }
    {
      title = "Desktop";
      href = "file://${home}/Desktop";
      icon = "user-desktop";
    }
    {
      title = "Documents";
      href = "file://${home}/Documents";
      icon = "folder-documents";
    }
    {
      title = "Downloads";
      href = "file://${home}/Downloads";
      icon = "folder-download";
    }
    {
      title = "Music";
      href = "file://${home}/Music";
      icon = "folder-music";
    }
    {
      title = "Pictures";
      href = "file://${home}/Pictures";
      icon = "folder-pictures";
    }
    {
      title = "Videos";
      href = "file://${home}/Videos";
      icon = "folder-videos";
    }
    {
      title = "Templates";
      href = "file://${home}/Templates";
      icon = "folder-templates";
    }
    {
      title = "Public";
      href = "file://${home}/Public";
      icon = "folder-public";
    }
    {
      title = "Projects";
      href = "file://${home}/Projects";
      icon = "folder-development";
    }
    {
      title = "Network";
      href = "remote:/";
      icon = "folder-network";
      system = true;
    }
    {
      title = "Trash";
      href = "trash:/";
      icon = "user-trash";
      system = true;
    }
    {
      title = "Recent Files";
      href = "recentlyused:/files";
      icon = "document-open-recent";
      system = true;
    }
    {
      title = "Recent Locations";
      href = "recentlyused:/locations";
      icon = "folder-open-recent";
      system = true;
    }
  ];

  mkBookmark = i: p: ''
    <bookmark href="${p.href}">
     <title>${p.title}</title>
     <info>
      <metadata owner="http://freedesktop.org">
       <bookmark:icon name="${p.icon}"/>
      </metadata>
      <metadata owner="http://www.kde.org">
       <ID>0/${toString i}</ID>${lib.optionalString (p.system or false) ''

      <isSystemItem>true</isSystemItem>''}
      </metadata>
     </info>
    </bookmark>'';

  userPlacesXbel = ''
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE xbel>
    <xbel xmlns:bookmark="http://www.freedesktop.org/standards/desktop-bookmarks" xmlns:kdepriv="http://www.kde.org/kdepriv" xmlns:mime="http://www.freedesktop.org/standards/shared-mime-info">
     <info>
      <metadata owner="http://www.kde.org">
       <kde_places_version>4</kde_places_version>
       <withRecentlyUsed>true</withRecentlyUsed>
       <withBaloo>true</withBaloo>
      </metadata>
     </info>
    ${lib.concatStringsSep "\n" (lib.imap0 mkBookmark places)}
    </xbel>
  '';

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
      dataDirs = builtins.concatStringsSep ":" (map (p: "${p}/share") ([pkgs.shared-mime-info pkgs.kdePackages.breeze-icons] ++ dolphinDeps));
      iconThemePkg = config.stylix.icons.package;
    in ''
      for exe in $out/bin/dolphin; do
        wrapProgram "$exe" \
          --prefix QT_PLUGIN_PATH : "${qtPluginPaths}" \
          --prefix XDG_DATA_DIRS : "${iconThemePkg}/share:${dataDirs}" \
          --prefix LD_LIBRARY_PATH : "${pkgs.pipewire}/lib"
      done
    '';
  };
in {
  # 1) Make Dolphin your default file manager
  xdg.mimeApps = {
    defaultApplications = {
      "inode/directory" = "org.kde.dolphin.desktop";
      "application/zip" = "org.kde.ark.desktop";
      "application/x-tar" = "org.kde.ark.desktop";
      "application/x-bzip-compressed-tar" = "org.kde.ark.desktop";
      "application/x-gzip" = "org.kde.ark.desktop";
      "application/x-xz" = "org.kde.ark.desktop";
      "application/x-7z-compressed" = "org.kde.ark.desktop";
      "application/x-rar" = "org.kde.ark.desktop";
    };
  };

  # 2) Fix for empty "Open With" menu under Hyprland
  xdg.configFile."menus/applications.menu".source = "${pkgs.kdePackages.plasma-workspace}/etc/xdg/menus/plasma-applications.menu";

  # 3) Drop in our "Extract Here" service menu
  xdg.configFile."kservices5/ServiceMenus/extracthere.desktop".text = extractHereDesktop;

  xdg.configFile."kdeglobals".text = ''
    [Icons]
    Theme=${config.stylix.icons.dark}
  '';

  xdg.configFile."dolphinrc".text = ''
    [UiSettings]
    ColorScheme=*

    [PreviewSettings]
    Plugins=appimagethumbnail,audiothumbnail,blenderthumbnail,comicbookthumbnail,cursorthumbnail,djvuthumbnail,ebookthumbnail,exrthumbnail,directorythumbnail,fontthumbnail,imagethumbnail,jpegthumbnail,kraorathumbnail,windowsexethumbnail,windowsimagethumbnail,mobithumbnail,opendocumentthumbnail,gsthumbnail,rawthumbnail,svgthumbnail,ffmpegthumbs
    EnableRemoteFolderThumbnail=true
    MaximumSize=21474836480
    MaximumRemoteSize=21474836480
  '';

  xdg.dataFile."user-places.xbel".text = userPlacesXbel;

  home.packages = [wrappedDolphin];
}
