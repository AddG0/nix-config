{pkgs, ...}: let
  # git-aware rsync: excludes .git and respects .gitignore / .git/info/exclude.
  # Pulled out of `scripts` so ghq-sync below can take it as a runtimeInput.
  gsync = pkgs.writeShellApplication {
    name = "gsync";
    runtimeInputs = with pkgs; [git rsync gnused coreutils];
    text = builtins.readFile ./gsync.sh;
  };

  # OTel auto-instrumentation bundle for Python, injected into otel-dev. distro +
  # OTLP/HTTP exporter (the gRPC path pulls compiled grpcio, which breaks across
  # interpreter versions) plus the common instrumentors. Drives zero-code tracing
  # via PYTHONPATH, mirroring the Node bundle and Java agent.
  otelPython = pkgs.python3.withPackages (ps:
    with ps; [
      opentelemetry-distro
      opentelemetry-exporter-otlp-proto-http
      opentelemetry-instrumentation-asgi
      opentelemetry-instrumentation-wsgi
      opentelemetry-instrumentation-dbapi
      opentelemetry-instrumentation-django
      opentelemetry-instrumentation-fastapi
      opentelemetry-instrumentation-flask
      opentelemetry-instrumentation-httpx
      opentelemetry-instrumentation-logging
      opentelemetry-instrumentation-psycopg2
      opentelemetry-instrumentation-redis
      opentelemetry-instrumentation-requests
      opentelemetry-instrumentation-sqlalchemy
      opentelemetry-instrumentation-sqlite3
      opentelemetry-instrumentation-urllib3
      opentelemetry-instrumentation-celery
      opentelemetry-instrumentation-system-metrics
    ]);
  otelPythonSite = "${otelPython}/${pkgs.python3.sitePackages}";
  scripts = {
    # Run a command and get a desktop notification when it finishes.
    # Linux uses notify-send (libnotify); macOS uses terminal-notifier.
    notify = pkgs.writeShellApplication {
      name = "notify";
      runtimeInputs =
        if pkgs.stdenv.isDarwin
        then [pkgs.terminal-notifier]
        else [pkgs.libnotify];
      text = builtins.readFile ./notify.sh;
    };
    # Pre-build devShells of one or more flake repos into the nix store.
    warm-flake-cache = pkgs.writeShellApplication {
      name = "warm-flake-cache";
      runtimeInputs = with pkgs; [nix-fast-build coreutils];
      text = builtins.readFile ./warm-flake-cache.sh;
    };
    # Optimize an image for GitLab group/project avatars (192x192, max 200 KiB).
    gitlab-avatar = pkgs.writeShellApplication {
      name = "gitlab-avatar";
      runtimeInputs = with pkgs; [imagemagick];
      text = builtins.readFile ./gitlab-avatar.sh;
    };
    # Run any dev command with OpenTelemetry auto-instrumentation, pointed at the
    # local collector. Node + JVM both covered; touches no repo files. The two
    # store paths are injected on top so otel-dev.sh stays a plain script.
    otel-dev = pkgs.writeShellApplication {
      name = "otel-dev";
      runtimeInputs = with pkgs; [coreutils];
      text =
        ''
          OTEL_NODE_BUNDLE="${pkgs.opentelemetry-node}/lib/node_modules"
          OTEL_JAVAAGENT_JAR="${pkgs.opentelemetry-javaagent}/share/java/opentelemetry-javaagent.jar"
          OTEL_PYTHON_AUTO="${otelPythonSite}/opentelemetry/instrumentation/auto_instrumentation"
          OTEL_PYTHON_SITE="${otelPythonSite}"
        ''
        + builtins.readFile ./otel-dev.sh;
    };
    inherit gsync;
    # Push the ghq repo you're in to the same path on another computer, via
    # gsync. Lives here (not ghq.nix) so it can depend on the gsync package.
    ghq-sync = pkgs.writeShellApplication {
      name = "ghq-sync";
      runtimeInputs = [gsync pkgs.ghq pkgs.git];
      text = builtins.readFile ./ghq-sync.sh;
    };
  };
in {
  home.packages = builtins.attrValues scripts;
}
