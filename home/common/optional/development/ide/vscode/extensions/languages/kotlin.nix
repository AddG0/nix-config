{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.fwcd.kotlin
  ];
  userSettings = {
    "kotlin.java.home" = "${pkgs.jdk}";
    "kotlin.languageServer.path" = "${pkgs.kotlin-language-server}/bin/kotlin-language-server";
  };
}
