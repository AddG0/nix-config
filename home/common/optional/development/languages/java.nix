{
  pkgs,
  inputs,
  lib,
  ...
}: let
  gradle = pkgs.gradle_9;

  # Reap by age: per-worktree store paths defeat Gradle's compat dedup, and jdtls's auto-import polling defeats its idle timeout.
  # Only IDLE daemons qualify (via `gradle --status`) so a daemon still hosting a live task (e.g. bootRun) is never killed underneath it.
  gradleDaemonReaper = pkgs.writeShellApplication {
    name = "gradle-daemon-reaper";
    runtimeInputs = [pkgs.procps gradle];
    text = ''
      max_age_minutes=90
      idle_pids=$(gradle --status | awk '$NF == "IDLE" {print $1}')
      for pid in $(pgrep -f GradleDaemon); do
        if ! grep -qx "$pid" <<<"$idle_pids"; then
          continue
        fi
        etimes=$(ps -o etimes= -p "$pid" | tr -d ' ')
        if [ -n "$etimes" ] && [ "$etimes" -gt "$((max_age_minutes * 60))" ]; then
          echo "gradle-daemon-reaper: stopping pid $pid, age $((etimes / 60))m"
          kill -TERM "$pid" || true
        fi
      done
    '';
  };

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
    gradle-completion
    gradleDaemonReaper
  ];

  systemd.user.services.gradle-daemon-reaper = {
    Unit.Description = "Stop Gradle daemons older than 90 minutes";
    Service = {
      Type = "oneshot";
      ExecStart = lib.getExe gradleDaemonReaper;
    };
  };

  systemd.user.timers.gradle-daemon-reaper = {
    Unit.Description = "Periodic stale Gradle daemon reap";
    Timer = {
      OnStartupSec = "5m";
      OnUnitActiveSec = "20m";
    };
    Install.WantedBy = ["timers.target"];
  };

  home.sessionVariables = {
    JAVA_HOME = "${pkgs.jdk}";
  };

  programs.git.ignores = lib.custom.gitignoreFromTemplates inputs.github-gitignore-templates [
    "Global/Eclipse"
    "Maven"
  ];

  programs.gradle = {
    enable = true;
    package = gradle;

    settings = {
      # Auto-detection walks the store looking for JDKs; home.file plants the ones we want.
      "org.gradle.java.installations.auto-detect" = "false";

      "org.gradle.parallel" = "true";
      "org.gradle.caching" = "true";
      "org.gradle.configuration-cache" = "true";
      "org.gradle.vfs.watch" = "true";

      "org.gradle.jvmargs" = "-Xmx4g -XX:MaxMetaspaceSize=768m -XX:+HeapDumpOnOutOfMemoryError -Dfile.encoding=UTF-8 ${lib.concatStringsSep " " errorproneCompilerArgs}";
      "org.gradle.workers.max" = "2";
      "org.gradle.daemon.idletimeout" = "1800000";
    };
  };
}
