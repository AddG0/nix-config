{
  pkgs,
  inputs,
  lib,
  ...
}: let
  # On the daemon JVM these make the errorprone plugin compile in-process instead of
  # forking a compiler JVM per task; those forks are never reaped (JEP 396 needs them).
  # See: https://github.com/tbroyer/gradle-errorprone-plugin (JDK 16+ / JPMS section)
  # Flag list: https://errorprone.info/docs/installation
  errorproneCompilerArgs = [
    "--add-exports=jdk.compiler/com.sun.tools.javac.api=ALL-UNNAMED"
    "--add-exports=jdk.compiler/com.sun.tools.javac.file=ALL-UNNAMED"
    "--add-exports=jdk.compiler/com.sun.tools.javac.main=ALL-UNNAMED"
    "--add-exports=jdk.compiler/com.sun.tools.javac.model=ALL-UNNAMED"
    "--add-exports=jdk.compiler/com.sun.tools.javac.parser=ALL-UNNAMED"
    "--add-exports=jdk.compiler/com.sun.tools.javac.processing=ALL-UNNAMED"
    "--add-exports=jdk.compiler/com.sun.tools.javac.tree=ALL-UNNAMED"
    "--add-exports=jdk.compiler/com.sun.tools.javac.util=ALL-UNNAMED"
    "--add-opens=jdk.compiler/com.sun.tools.javac.code=ALL-UNNAMED"
    "--add-opens=jdk.compiler/com.sun.tools.javac.comp=ALL-UNNAMED"
  ];
in {
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
    org.gradle.jvmargs=-Xmx4g -XX:MaxMetaspaceSize=768m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8 ${lib.concatStringsSep " " errorproneCompilerArgs}
    org.gradle.workers.max=2
    org.gradle.daemon.idletimeout=1800000
  '';
}
