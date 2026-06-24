# OpenTelemetry Java agent extension that adds a span per configured method,
# carrying the call's argument values (code.args.N). Driven by the same
# OTEL_DEV_METHOD_ARGS_INCLUDE list otel-dev generates from compiled classes.
#
# Compiled with plain javac (no Gradle/network): ByteBuddy + the extension API come
# from the agent jar's own `inst/` classes (exact matching version); only the
# unshaded opentelemetry-api/context are fetched, since the agent ships those shaded.
{
  lib,
  stdenvNoCC,
  jdk,
  unzip,
  fetchurl,
  opentelemetry-javaagent,
}: let
  otelApi = fetchurl {
    url = "https://repo1.maven.org/maven2/io/opentelemetry/opentelemetry-api/1.62.0/opentelemetry-api-1.62.0.jar";
    sha256 = "07a31gj3130m6vrv70kabvfynrx7z0pjiwbb7rjk74h4ij9470fm";
  };
  otelContext = fetchurl {
    url = "https://repo1.maven.org/maven2/io/opentelemetry/opentelemetry-context/1.62.0/opentelemetry-context-1.62.0.jar";
    sha256 = "05z5vgdplyg715a1b85d30gqsa0w3x61ah5z0xirnar214v6rj4f";
  };
  agentJar = "${opentelemetry-javaagent}/share/java/opentelemetry-javaagent.jar";
in
  stdenvNoCC.mkDerivation {
    pname = "opentelemetry-method-args";
    version = "1.0.0";
    src = ./src;
    nativeBuildInputs = [jdk unzip];

    buildPhase = ''
      runHook preBuild
      # Pull ByteBuddy + the extension API out of the agent jar as compile deps. The
      # `inst/` prefix and `.classdata` suffix keep the agent from loading them; strip
      # both so they form a normal classpath root.
      unzip -q "${agentJar}" \
        'inst/net/bytebuddy/*' \
        'inst/io/opentelemetry/javaagent/extension/*' \
        'inst/io/opentelemetry/sdk/autoconfigure/spi/*' \
        -d agentcp
      find agentcp/inst -name '*.classdata' | while read -r f; do
        mv "$f" "''${f%.classdata}.class"
      done

      mkdir -p out
      javac -proc:none -nowarn \
        -cp "agentcp/inst:${otelApi}:${otelContext}" \
        -d out $(find "$src" -name '*.java')
      cp -r "$src/resources/META-INF" out/META-INF
      jar cf opentelemetry-method-args.jar -C out .
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/java
      cp opentelemetry-method-args.jar $out/share/java/
      runHook postInstall
    '';

    meta = with lib; {
      description = "OpenTelemetry Java agent extension: per-method spans with argument values";
      license = licenses.asl20;
      platforms = platforms.all;
    };
  }
