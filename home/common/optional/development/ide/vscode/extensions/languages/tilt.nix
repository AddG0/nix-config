{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.tilt-dev.tiltfile
  ];
  userSettings = {
    "tiltfile.tilt.path" = "${pkgs.tilt}/bin/tilt";
  };
}
