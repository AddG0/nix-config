{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.ryu1kn.partial-diff
  ];
  userSettings = {
    "partialDiff.enableTelemetry" = false;
  };
}
