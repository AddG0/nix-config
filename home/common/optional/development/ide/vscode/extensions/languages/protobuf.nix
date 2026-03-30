{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.drblury.protobuf-vsc
  ];
  userSettings = {
    "protobuf.externalLinter.enabled" = true;
    "protobuf.externalLinter.linter" = "buf";
    "protobuf.includes" = ["\${workspaceFolder}/proto"];
  };
}
