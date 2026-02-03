{pkgs, ...}: {
  extensions = [
    pkgs.vscode-extensions.zxh404.vscode-proto3
  ];
  userSettings = {
    "protoc" = {
      "path" = "${pkgs.protobuf}/bin/protoc";
    };
    "clang-format.executable" = "${pkgs.clang-tools}/bin/clang-format";
  };
}
