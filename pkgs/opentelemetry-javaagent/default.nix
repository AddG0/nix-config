# OpenTelemetry Java auto-instrumentation agent for automatic trace/metric collection
# Usage: Add -javaagent:/path/to/opentelemetry-javaagent.jar to JVM args
{
  lib,
  stdenvNoCC,
  fetchurl,
}:
stdenvNoCC.mkDerivation rec {
  pname = "opentelemetry-javaagent";
  version = "2.28.1";

  src = fetchurl {
    url = "https://github.com/open-telemetry/opentelemetry-java-instrumentation/releases/download/v${version}/opentelemetry-javaagent.jar";
    hash = "sha256-+qib3uv5sfUr5KQ3RokXZxewKlnfLY+LbrmqOfkpJYk=";
  };

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/java
    cp $src $out/share/java/opentelemetry-javaagent.jar
    runHook postInstall
  '';

  meta = with lib; {
    description = "OpenTelemetry Java auto-instrumentation agent";
    homepage = "https://github.com/open-telemetry/opentelemetry-java-instrumentation";
    license = licenses.asl20;
    platforms = platforms.all;
  };
}
