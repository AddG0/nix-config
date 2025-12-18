{pkgs}: {
  extensions = [
    pkgs.vscode-marketplace.ritwickdey.liveserver
  ];
  userSettings = {
    "liveServer.settings.donotShowInfoMsg" = true;
    "liveServer.settings.donotVerifyTags" = true;
  };
}
