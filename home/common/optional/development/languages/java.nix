{pkgs, ...}: {
  home.packages = with pkgs; [
    jdk
    maven
    gradle
  ];

  home.sessionVariables = {
    JAVA_HOME = "${pkgs.jdk}";
  };

  home.file.".gradle/gradle.properties".text = ''
    # NixOS Compatibility
    org.gradle.java.installations.auto-detect=false

    # Performance Optimizations
    org.gradle.parallel=true
    org.gradle.caching=true
    org.gradle.configuration-cache=true
    org.gradle.vfs.watch=true

    # Gradle Daemon Settings
    org.gradle.jvmargs=-Xmx2g -XX:MaxMetaspaceSize=512m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8
  '';
}
