# OpenTelemetry auto-instrumentation bundle for Node.js
# Provides node_modules so repos get zero-code tracing without adding a dependency.
# Usage: NODE_OPTIONS="--require @opentelemetry/auto-instrumentations-node/register"
#        NODE_PATH="${opentelemetry-node}/lib/node_modules"
{
  lib,
  buildNpmPackage,
}:
buildNpmPackage {
  pname = "opentelemetry-node";
  version = "1.0.0";

  src = ./.;
  npmDepsHash = "sha256-mtsyEKXwA76hq8FmFI9r9i39GPW7PL6qT64Z8mnpGtY=";

  # Dependency-only bundle: nothing to compile, we just want node_modules.
  dontNpmBuild = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib
    cp -r node_modules $out/lib/node_modules
    # register.js (the --require entrypoint) + the http2 instrumentation it pulls
    # in. Placed beside node_modules so their @opentelemetry/* requires resolve.
    cp ${./register.js} $out/lib/register.js
    cp ${./http2-register.js} $out/lib/http2-register.js
    runHook postInstall
  '';

  # Synthetic local bundle: no upstream src/version for nix-update to track.
  # Bumping deps means regenerating package-lock.json + npmDepsHash by hand.
  passthru.nixUpdate.version = "skip";

  meta = with lib; {
    description = "OpenTelemetry auto-instrumentation node_modules bundle for zero-touch Node tracing";
    homepage = "https://github.com/open-telemetry/opentelemetry-js-contrib";
    license = licenses.asl20;
    platforms = platforms.all;
  };
}
