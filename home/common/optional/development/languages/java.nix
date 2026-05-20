{
  pkgs,
  inputs,
  lib,
  ...
}: {
  home.packages = with pkgs; [
    jdk
    maven
    gradle_9
    gradle-completion
  ];

  home.sessionVariables = {
    JAVA_HOME = "${pkgs.jdk}";
  };

  programs.git.ignores = lib.custom.gitignoreFromTemplates inputs.github-gitignore-templates [
    "Global/Eclipse"
    "Maven"
  ];

  home.file.".gradle/gradle.properties".text = ''
    # NixOS Compatibility
    org.gradle.java.installations.auto-detect=false

    # Performance Optimizations
    org.gradle.parallel=true
    org.gradle.caching=true
    org.gradle.configuration-cache=true
    org.gradle.vfs.watch=true

    # Gradle Daemon Settings
    org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=768m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
    org.gradle.workers.max=4
    org.gradle.daemon.idletimeout=1800000
  '';
}
