{pkgs, ...}: {
  # All Java extensions must use -release to avoid OSGi bundle version conflicts
  # They're released together as a pack and have interdependent bundles
  extensions = [
    pkgs.vscode-marketplace-release.redhat.java
    pkgs.vscode-marketplace-release.vscjava.vscode-java-debug
    pkgs.vscode-marketplace-release.vscjava.vscode-java-test
    pkgs.vscode-marketplace-release.vscjava.vscode-maven
    pkgs.vscode-marketplace-release.vscjava.vscode-java-dependency
    pkgs.vscode-marketplace-release.vscjava.vscode-gradle
    pkgs.vscode-marketplace.vmware.vscode-spring-boot
    pkgs.vscode-marketplace.vscjava.vscode-spring-initializr
  ];
  userSettings = {
    # Use Nix-provided JDK/Maven for language servers (bundled JRE doesn't work on NixOS)
    "java.jdt.ls.java.home" = "${pkgs.jdk}";
    "java.configuration.runtimes" = [
      {
        name = "JavaSE-17";
        path = "${pkgs.jdk17}/lib/openjdk";
      }
      {
        name = "JavaSE-21";
        path = "${pkgs.jdk21}/lib/openjdk";
        default = true;
      }
      {
        name = "JavaSE-25";
        path = "${pkgs.jdk25}/lib/openjdk";
      }
    ];
    "spring-boot.ls.java.home" = "${pkgs.jdk}";
    # Explicit log path required on NixOS to avoid read-only filesystem errors
    "spring-boot.ls.logfile" = "/tmp/spring-boot-ls.log";
    "java.import.gradle.java.home" = "${pkgs.jdk}";
    "java.import.gradle.home" = "${pkgs.gradle}";
    "maven.executable.path" = "${pkgs.maven}/bin/mvn";

    # JDT Language Server memory/performance settings
    # Clear JAVA_TOOL_OPTIONS to prevent direnv interference
    "java.jdt.ls.vmargs" = "-XX:+UseParallelGC -XX:GCTimeRatio=4 -XX:AdaptiveSizePolicyWeight=90 -Xmx10G -Xms512m";
    "java.configuration.updateBuildConfiguration" = "automatic";
    "java.compile.nullAnalysis.mode" = "automatic";
    "java.inlayHints.parameterNames.enabled" = "all";

    "java.maxConcurrentBuilds" = 10;
    "java.codeGeneration.hashCodeEquals.useJava7Objects" = true;
    "java.codeGeneration.toString.template" = "\${object.className} {\${member.name()}=\${member.value}, \${otherMembers}}";

    # Exclude directories from Java project import
    # .direnv contains Nix store symlinks that cause read-only filesystem errors
    "java.import.exclusions" = [
      "**/node_modules/**"
      "**/.metadata/**"
      "**/archetype-resources/**"
      "**/META-INF/maven/**"
      "**/.direnv/**"
      "**/.devenv/**"
    ];
    "java.project.resourceFilters" = [
      "node_modules"
      "\\.git"
      ".direnv"
      ".devenv"
    ];
  };
}
