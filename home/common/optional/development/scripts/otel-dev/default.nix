# otel-dev: run any dev command with OpenTelemetry zero-code auto-instrumentation
# (Node + JVM + Python), pointed at the local collector. The wrapper logic lives
# in otel-dev.sh; this derivation injects the Nix store paths it needs on top.
{
  lib,
  runCommand,
  python3,
  coreutils,
  gnugrep,
  gnused,
  gawk,
  findutils,
  opentelemetry-node,
  opentelemetry-javaagent,
  opentelemetry-method-args,
  writeShellApplication,
}: let
  # Derives OTEL_INSTRUMENTATION_METHODS_INCLUDE from a JVM project's compiled
  # classes so the Java agent spans the app's own business methods, no app code.
  # javap comes from the project's JDK on the inherited PATH (skips if absent).
  otelJavaMethods = writeShellApplication {
    name = "otel-java-methods";
    runtimeInputs = [coreutils gnugrep gnused gawk findutils];
    text = builtins.readFile ./otel-java-methods.sh;
  };
  # OTel auto-instrumentation bundle for Python. distro + OTLP/HTTP exporter (the
  # gRPC path pulls compiled grpcio, which breaks across interpreter versions)
  # plus the common instrumentors. Drives zero-code tracing via PYTHONPATH,
  # mirroring the Node bundle and Java agent.
  otelPython = python3.withPackages (ps:
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
      # system-metrics dropped: needs psutil, a compiled module with no pure
      # fallback, which fails to import on any app CPython != this nixpkgs one.
      # Pure chardet so the kept requests (exporter dep) finds a char detector
      # without the compiled charset-normalizer it would otherwise pull in.
      chardet
    ]);
  otelPythonSite = "${otelPython}/${python3.sitePackages}";
  # Exposing the whole env on PYTHONPATH shadows the app's own flask/django/
  # requests/pydantic/... (PYTHONPATH outranks the app venv), pinning wrong
  # versions and — worse — loading cp-locked .so files that break under a
  # different app interpreter. So expose ONLY opentelemetry + its pure support
  # deps and let the app provide the libs the instrumentors patch. Allowlist by
  # prefix (not blocklist) so a new instrumentor auto-excludes its target lib.
  # requests is kept because the OTLP/HTTP exporter imports it directly.
  otelPythonKeep = [
    "opentelemetry"
    "sitecustomize.py"
    "deprecated"
    "Deprecated"
    "wrapt"
    "importlib_metadata"
    "zipp"
    "packaging"
    "typing_extensions"
    "google"
    "protobuf"
    "googleapis_common_protos"
    "six"
    "toml"
    "setuptools"
    "pkg_resources"
    "_distutils_hack"
    "_sysconfigdata"
    "requests"
    "urllib3"
    "certifi"
    "idna"
    "chardet"
  ];
  otelPythonPath = runCommand "otel-python-path" {} ''
    mkdir -p "$out"
    cd "${otelPythonSite}"
    shopt -s nullglob
    for prefix in ${lib.escapeShellArgs otelPythonKeep}; do
      for entry in "$prefix"*; do
        # -fn so overlapping prefixes (google vs googleapis_*) relink instead of
        # descending into an already-linked dir.
        ln -sfn "${otelPythonSite}/$entry" "$out/$entry"
      done
    done
  '';
in
  writeShellApplication {
    name = "otel-dev";
    runtimeInputs = [coreutils];
    text =
      ''
        OTEL_NODE_BUNDLE="${opentelemetry-node}/lib/node_modules"
        OTEL_NODE_REGISTER="${opentelemetry-node}/lib/register.js"
        OTEL_JAVAAGENT_JAR="${opentelemetry-javaagent}/share/java/opentelemetry-javaagent.jar"
        OTEL_METHOD_ARGS_JAR="${opentelemetry-method-args}/share/java/opentelemetry-method-args.jar"
        OTEL_JAVA_METHODS_GEN="${otelJavaMethods}/bin/otel-java-methods"
        OTEL_PYTHON_AUTO="${otelPythonPath}/opentelemetry/instrumentation/auto_instrumentation"
        OTEL_PYTHON_SITE="${otelPythonPath}"
      ''
      + builtins.readFile ./otel-dev.sh;
  }
