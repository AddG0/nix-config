{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.orta.vscode-jest
  ];
  userSettings = {
    # Jest Runner
    "jest.autoRun" = "off";
    "jest.showCoverageOnLoad" = false;
    "jest.runMode" = "on-demand";
  };
}
