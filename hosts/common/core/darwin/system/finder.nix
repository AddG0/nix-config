{config, ...}: {
  # customize finder
  system.defaults.finder = {
    _FXSortFoldersFirst = true; # sort folders first
    _FXShowPosixPathInTitle = true; # show full path in finder title
    AppleShowAllExtensions = true; # show all file extensions
    FXEnableExtensionChangeWarning = false; # disable warning when changing file extension
    AppleShowAllFiles = true; # show hidden files

    # When performing a search, search the current folder by default
    FXDefaultSearchScope = "SCcf";

    QuitMenuItem = true; # enable quit menu item
    ShowPathbar = true; # show path bar
    ShowStatusBar = true; # show status bar
    # default finder view. “icnv” = Icon view, “Nlsv” = List view, “clmv” = Column View, “Flwv” = Gallery View The default is icnv.
    FXPreferredViewStyle = "clmv";

    NewWindowTarget = "Other";
    NewWindowTargetPath = "file:///Users/${config.hostSpec.username}/home"; # open new finder window in the current folder

    # Desktop specific settings
    CreateDesktop = false; # showing files on desktop
    ShowExternalHardDrivesOnDesktop = false; # show external hard drives on desktop
    ShowHardDrivesOnDesktop = false; # show hard drives on desktop
    ShowMountedServersOnDesktop = false; # show mounted servers on desktop
    ShowRemovableMediaOnDesktop = false; # show removable media on desktop
  };
}
