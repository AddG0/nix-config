{pkgs, ...}: {
  extensions = [
    pkgs.vscode-marketplace.redhat.java
    pkgs.vscode-marketplace.vscjava.vscode-java-debug
    pkgs.vscode-marketplace.vscjava.vscode-java-test
    pkgs.vscode-marketplace.vscjava.vscode-maven
    pkgs.vscode-marketplace.vscjava.vscode-java-dependency
  ];
  userSettings = {
    "java.configuration.updateBuildConfiguration" = "automatic";
    "java.compile.nullAnalysis.mode" = "automatic";
    "java.inlayHints.parameterNames.enabled" = "all";
    "java.codeGeneration.hashCodeEquals.useJava7Objects" = true;
    "java.codeGeneration.toString.template" = "\${object.className} {\${member.name()}=\${member.value}, \${otherMembers}}";
  };
}
