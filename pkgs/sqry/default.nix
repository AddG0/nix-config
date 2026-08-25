{
  lib,
  stdenvNoCC,
  fetchurl,
}:
# The musl release binaries are fully static, so no autoPatchelf.
stdenvNoCC.mkDerivation (finalAttrs: let
  arches = {
    x86_64-linux = "x86_64";
    aarch64-linux = "arm64";
  };
  arch = arches.${stdenvNoCC.hostPlatform.system} or (throw "sqry: no published build for ${stdenvNoCC.hostPlatform.system}");

  hashes = {
    x86_64 = {
      sqry = "sha256-TGXt7EhkDj1I8Od6xzaePvDHHwBRB1PjuZ5sNWIJIBE=";
      sqry-mcp = "sha256-8Q55wI0yVlXv1m4gppoSJCDOEOiScsy+T8pTob11eRA=";
    };
    arm64 = {
      sqry = "sha256-kgWq/rE6Xs5VmlfGZ5SOdI9lMPOGb37mySE8xB+9RFM=";
      sqry-mcp = "sha256-/NdT60RMlLHKH16u3bXxx280vzvrQAgSp6GD4C4lEaA=";
    };
  };

  fetchBin = name:
    fetchurl {
      url = "https://github.com/verivus-oss/sqry/releases/download/v${finalAttrs.version}/${name}-linux-${arch}-musl";
      hash = hashes.${arch}.${name};
    };
in {
  pname = "sqry";
  version = "30.0.0";

  dontUnpack = true;

  installPhase = ''
    runHook preInstall
    install -Dm755 ${fetchBin "sqry"} $out/bin/sqry
    install -Dm755 ${fetchBin "sqry-mcp"} $out/bin/sqry-mcp
    runHook postInstall
  '';

  meta = {
    description = "Structural semantic code search over ASTs";
    homepage = "https://sqry.dev";
    license = lib.licenses.mit;
    platforms = builtins.attrNames arches;
    mainProgram = "sqry";
  };
})
