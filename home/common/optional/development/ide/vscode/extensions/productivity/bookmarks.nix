{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.alefragnani.bookmarks
  ];
  userSettings = {
    "bookmarks.saveBookmarksInProject" = true;
    "bookmarks.navigateThroughAllFiles" = true;
    "bookmarks.sideBar.expanded" = true;
  };
}
