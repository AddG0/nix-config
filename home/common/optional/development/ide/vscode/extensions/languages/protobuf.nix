{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.drblury.protobuf-vsc
  ];
  userSettings = {
    "protoc" = {
      "path" = "${pkgs.protobuf}/bin/protoc";
    };
    "clang-format.executable" = "${pkgs.clang-tools}/bin/clang-format";
    "protobuf.externalLinter.enabled" = true;
    "protobuf.externalLinter.linter" = "buf";
  };
}
